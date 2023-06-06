module Wit.Check
  ( CheckError (..),
    parseFile,
    trackFile,
    check,
    emptyCheckState,
    CheckResult (..),
    TyEnv,
    Context,
  )
where

import Algebra.Graph.AdjacencyMap (AdjacencyMap, connect, empty, overlays, vertex)
import Algebra.Graph.ToGraph (ToGraph (topSort))
import Control.Monad (forM, forM_)
import Control.Monad.Except (MonadError (..), MonadIO (..))
import Control.Monad.Reader (MonadReader (ask))
import Control.Monad.State (MonadState (get, put), StateT (runStateT), modify)
import Data.Map.Lazy ((!?))
import Data.Map.Lazy qualified as M
import Prettyprinter
import System.Directory
import System.FilePath (normalise, (</>))
import Text.Megaparsec (SourcePos, errorBundlePretty, parse, sourcePosPretty)
import Wit.Ast
import Wit.Parser (ParserError, pWitFile)
import Wit.TypeValue (TypeSig (..), TypeVal (..))

data CheckError
  = PErr ParserError
  | CheckError String (Maybe SourcePos)
  | Bundle [CheckError]

instance Pretty CheckError where
  pretty e = go e <> line
    where
      go :: CheckError -> Doc ann
      go (PErr parseErr) = pretty $ errorBundlePretty parseErr
      go (CheckError msg (Just pos)) = pretty (sourcePosPretty pos) <> colon <+> pretty msg
      go (CheckError msg Nothing) = pretty msg
      go (Bundle es) = vsep (map go es)

type Name = String

type TyEnv = M.Map Name TypeVal

type Context = M.Map Name TypeSig

data CheckState = CheckState
  { errors :: [CheckError],
    -- maps type name to its type value
    -- this is created for type definition
    typeEnvironment :: TyEnv,
    -- maps func or resource to its signature
    -- foo : func (x1 : A1, x2 : A2, ...) -> R
    context :: Context
  }

updateEnvironment :: (MonadState CheckState m) => Name -> TypeVal -> m ()
updateEnvironment name ty = do
  checkState <- get
  put $ checkState {typeEnvironment = M.insert name ty checkState.typeEnvironment}

updateContext :: (MonadState CheckState m) => Name -> TypeSig -> m ()
updateContext name ty = do
  checkState <- get
  put $ checkState {context = M.insert name ty checkState.context}

data CheckResult = CheckResult
  { tyEnv :: TyEnv,
    ctx :: Context
  }

emptyCheckState :: CheckState
emptyCheckState = CheckState [] M.empty M.empty

collect :: (MonadState CheckState m, MonadError CheckError m) => m () -> m ()
collect ma = ma `catchError` (\e -> modify (\s -> s {errors = e : s.errors}))

bundle :: (MonadState CheckState m, MonadError CheckError m) => m ()
bundle = do
  s <- get
  case s.errors of
    [] -> return ()
    _ -> do
      put (s {errors = []})
      throwError $ Bundle $ reverse s.errors

report :: (MonadError CheckError m) => String -> m a
report msg = throwError $ CheckError msg Nothing

addPos :: (MonadError CheckError m) => SourcePos -> m a -> m a
addPos pos = withError updatePos
  where
    updatePos :: CheckError -> CheckError
    updatePos (CheckError msg Nothing) = CheckError msg (Just pos)
    updatePos (Bundle es) = Bundle $ map updatePos es
    updatePos e = e

evaluateType :: (MonadState CheckState m, MonadError CheckError m) => Type -> m TypeVal
evaluateType (SrcPosType pos ty) = addPos pos $ evaluateType ty
evaluateType PrimString = return TyString
evaluateType PrimUnit = return TyUnit
evaluateType PrimU8 = return TyU8
evaluateType PrimU16 = return TyU16
evaluateType PrimU32 = return TyU32
evaluateType PrimU64 = return TyU64
evaluateType PrimI8 = return TyI8
evaluateType PrimI16 = return TyI16
evaluateType PrimI32 = return TyI32
evaluateType PrimI64 = return TyI64
evaluateType PrimChar = return TyChar
evaluateType PrimF32 = return TyF32
evaluateType PrimF64 = return TyF64
evaluateType (Optional ty) = TyOptional <$> evaluateType ty
evaluateType (ListTy ty) = TyList <$> evaluateType ty
evaluateType (ExpectedTy ty1 ty2) = TyExpected <$> evaluateType ty1 <*> evaluateType ty2
evaluateType (TupleTy tys) = TyTuple <$> mapM evaluateType tys
evaluateType (Defined name) = do
  checkState <- get
  case M.lookup name checkState.typeEnvironment of
    Just (TyRef n) -> return (TyRef n)
    Just (TyExternRef m n) -> return (TyExternRef m n)
    -- stuck other type value in resolving here, since expanded a ref is not wanted here
    -- we will, however, expand a ref in codegen
    Just _ -> return (TyRef name)
    Nothing -> report $ "Type `" <> name <> "` not found"

trackFile ::
  (MonadIO m, MonadError CheckError m, MonadReader FilePath m) =>
  FilePath ->
  m ([FilePath], M.Map FilePath WitFile)
trackFile filepath = do
  (depGraph, parsed) <- runStateT (go filepath) M.empty
  let todoList = topSort depGraph
  case todoList of
    Left c -> throwError $ CheckError (filepath <> ": cyclic dependency\n  " <> show c) Nothing
    Right r -> return (reverse r, parsed)
  where
    go ::
      (MonadIO m, MonadState (M.Map FilePath WitFile) m, MonadError CheckError m, MonadReader FilePath m) =>
      FilePath ->
      m (AdjacencyMap FilePath)
    go path = do
      wit_ast <- parseFile path
      modify (M.insert path wit_ast)
      let deps = map (<> ".wit") $ dependencies (use_list wit_ast)
      let g = map (connect (vertex path) . vertex) deps
      gs <- forM deps $ \dep -> do
        visited <- get
        if M.member dep visited
          then return empty
          else go dep
      return $ overlays $ gs ++ g

parseFile :: (MonadIO m, MonadError CheckError m, MonadReader FilePath m) => FilePath -> m WitFile
parseFile filepath = do
  workingDir <- ask
  content <- liftIO $ readFile $ workingDir </> filepath
  case parse pWitFile filepath content of
    Left e -> throwError $ PErr e
    Right ast -> return ast

checkFile ::
  (MonadIO m, MonadError CheckError m, MonadState CheckState m, MonadReader FilePath m) =>
  FilePath ->
  m CheckResult
checkFile path = do
  -- working directory concept
  -- 1. for file checking, the locaiton directory of file is the working directory
  --    e.g. a/b/c/xxx.wit, then working directory is a/b/c
  -- 2. for directory checking, the directory is the working directory
  workingDir <- ask
  -- ensure file exist in working directory
  existed <- liftIO $ doesFileExist $ workingDir </> path
  if existed
    then do
      -- checking files recursively
      ast <- parseFile path
      check ast
    else report $ "no file `" <> path <> "` in `" <> normalise workingDir <> "`"

check ::
  (MonadIO m, MonadError CheckError m, MonadState CheckState m, MonadReader FilePath m) =>
  WitFile ->
  m CheckResult
check wit_file = do
  forM_ (use_list wit_file) (collect . checkUseFileExisted)
  bundle
  introUseIdentifiers $ use_list wit_file
  forM_ wit_file.definition_list defineType
  forM_ (definition_list wit_file) (collect . defineTerm)
  bundle
  checkState <- get
  return
    CheckResult
      { tyEnv = checkState.typeEnvironment,
        ctx = checkState.context
      }
  where
    introUseIdentifiers :: (MonadState CheckState m) => [Use] -> m ()
    introUseIdentifiers us = do
      forM_ us extend
      where
        extend (SrcPosUse _pos u) = extend u
        extend (Use imports moduleName) = do
          forM_ imports $ \(_, name) -> do
            updateEnvironment name (TyExternRef moduleName name)
        extend (UseAll _) = return ()

checkUseFileExisted ::
  (MonadIO m, MonadError CheckError m, MonadState CheckState m, MonadReader FilePath m) =>
  Use ->
  m ()
checkUseFileExisted (SrcPosUse pos u) = addPos pos $ checkUseFileExisted u
checkUseFileExisted (Use imports mod_name) = checkModFileExisted imports mod_name
checkUseFileExisted (UseAll mod_name) = checkModFileExisted [] mod_name

checkModFileExisted ::
  (MonadIO m, MonadError CheckError m, MonadState CheckState m, MonadReader FilePath m) =>
  [(SourcePos, String)] ->
  String ->
  m ()
checkModFileExisted requires mod_name = do
  let module_file = mod_name ++ ".wit"
  checkResult <- checkFile module_file
  forM_ requires $ \(pos, req) -> do
    collect $ addPos pos $ ensureRequire checkResult.tyEnv req

  bundle
  where
    -- ensure required types are defined in the imported module
    ensureRequire :: (MonadError CheckError m) => TyEnv -> String -> m ()
    ensureRequire env req =
      case env !? req of
        Just _ -> return ()
        Nothing -> report ("no type `" ++ req ++ "` in module `" ++ mod_name ++ "`")

defineType :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
defineType (SrcPos _ def) = defineType def
defineType (Enum name cs) = updateEnvironment name $ TyEnum cs
defineType (Record name fields) = do
  updateEnvironment name (TyRef name)
  fs <-
    forM
      fields
      ( \(field_name, ty) -> do
          ty' <- evaluateType ty
          return (field_name, ty')
      )
  updateEnvironment name (TyRecord fs)

-- as a sum of product, it's ok to be defined recursively
defineType (Variant name cases) = do
  updateEnvironment name (TyRef name)
  cs <- forM cases $
    \(case_name, tys) -> do
      tys' <- mapM evaluateType tys
      return (case_name, TyTuple tys')
  updateEnvironment name (TySum cs)
-- Notice that, type alias though can have recursive definition, but it should be invalid
-- Since we will have no idea how to deal with `type A = A`
--
-- Due to linear check, we also avoid circular definition like `type A = B; type B = A`
-- The first definition will failed
--
-- Of course, we can have more complicated definition `type A = C A` might be valid in some languages
-- but that is also a thing we would like to avoid
defineType (TypeAlias name ty) = do
  tyv <- evaluateType ty
  updateEnvironment name tyv
-- resource is not only a term definer, but also a type definer
-- it will have a handle i32 as type value
defineType (Resource name _) = updateEnvironment name TyU32
defineType (Func _) = return ()

defineTerm :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
defineTerm (SrcPos pos def) = addPos pos $ defineTerm def
defineTerm (Func f) = defineFn f
defineTerm (Resource resource_name func_list) =
  forM_
    func_list
    ( \(attr, Function name binders retTyp) -> do
        let fn =
              ( case attr of
                  -- e.g.
                  -- `static open: func(name: string) -> expected<keyvalue, keyvalue-error>`
                  -- ~> out of resource
                  -- `keyvalue_open: func(name: string) -> expected<keyvalue, keyvalue-error>`
                  Static -> Function (resource_name <> "_" <> name) binders retTyp
                  -- e.g.
                  -- `get: func(key: string) -> expected<list<u8>, keyvalue-error> `
                  -- ~> out of resource
                  -- `keyvalue_get: func(handle: keyvalue, key: string) -> expected<list<u8>, keyvalue-error> `
                  Member -> Function (resource_name <> "_" <> name) (("handle", Defined resource_name) : binders) retTyp
              )
        defineFn fn
    )
defineTerm _ = return ()

defineFn :: (MonadError CheckError m, MonadState CheckState m) => Function -> m ()
defineFn (Function name binders result_ty) = do
  binders' <- mapM (\(p, pTy) -> do pTy' <- evaluateType pTy; return (p, pTy')) binders
  resultTy <- evaluateType result_ty
  updateContext name (TyArrow binders' resultTy)

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
withError :: MonadError e m => (e -> e) -> m a -> m a
withError f action = tryError action >>= either (throwError . f) pure

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
tryError :: MonadError e m => m a -> m (Either e a)
tryError act = (Right <$> act) `catchError` (pure . Left)
