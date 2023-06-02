module Wit.Check
  ( CheckError (..),
    parseFile,
    check,
    emptyCheckState,
  )
where

import Control.Monad
import Control.Monad.Except
import Control.Monad.Reader
import Control.Monad.State
import Data.Map.Lazy qualified as M
import Data.Maybe
import Prettyprinter
import System.Directory
import System.FilePath
import Text.Megaparsec
import Wit.Ast
import Wit.Parser (ParserError, pWitFile)
import Wit.TypeValue

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

data CheckState = CheckState
  { errors :: [CheckError],
    environment :: M.Map Name TypeVal
  }

emptyCheckState :: CheckState
emptyCheckState = CheckState [] M.empty

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

type Name = String

lookupEnvironment :: (MonadState CheckState m, MonadError CheckError m) => Name -> m TypeVal
lookupEnvironment name = do
  ctx <- gets environment
  case M.lookup name ctx of
    Just ty -> return ty
    Nothing -> report $ "Type `" <> name <> "` not found"

updateEnvironment :: (MonadState CheckState m) => Name -> TypeVal -> m ()
updateEnvironment name ty = do
  s <- get
  put $ s {environment = M.insert name ty $ environment s}

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
evaluateType (Defined name) = return $ TyRef name

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
  m WitFile
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
  m WitFile
check wit_file = do
  forM_ (use_list wit_file) (collect . checkUseFileExisted)
  bundle
  introUseIdentifiers $ use_list wit_file
  forM_ wit_file.definition_list defineType
  forM_ (definition_list wit_file) (collect . checkDef)
  bundle
  return wit_file
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
  m <- checkFile module_file
  forM_ requires $ \(pos, req) -> do
    collect $ addPos pos $ ensureRequire (mapMaybe collectTypeName m.definition_list) req

  bundle
  where
    -- ensure required types are defined in the imported module
    ensureRequire :: (MonadError CheckError m) => [String] -> String -> m ()
    ensureRequire types req =
      unless (req `elem` types) $
        report ("no type `" ++ req ++ "` in module `" ++ mod_name ++ "`")

    collectTypeName :: Definition -> Maybe String
    collectTypeName (SrcPos _ d) = collectTypeName d
    collectTypeName (Resource name _) = Just name
    collectTypeName (Enum name _) = Just name
    collectTypeName (Record name _) = Just name
    collectTypeName (TypeAlias name _) = Just name
    collectTypeName (Variant name _) = Just name
    collectTypeName (Func _) = Nothing

toTuple :: (MonadError CheckError m, MonadState CheckState m) => [Type] -> m TypeVal
toTuple ts = do
  vs <- forM ts evaluateType
  return $ TyTuple vs

defineType :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
defineType (SrcPos _ def) = defineType def
defineType (Enum name _) = updateEnvironment name TyU32
defineType (Record name fields) = do
  t <- toTuple (map snd fields)
  updateEnvironment name t
defineType (TypeAlias name ty) = do
  tyv <- evaluateType ty
  updateEnvironment name tyv
-- as a sum of product, it's ok to be defined recursively
defineType (Variant name cases) = do
  cs <- forM cases $ do
    toTuple . snd
  updateEnvironment name (TySum name cs)
-- resource is not only a term definer, but also a type definer
defineType (Resource name _) = updateEnvironment name (TyRef name)
defineType (Func _) = return ()

-- insert type definition into Env
-- e.g.
--            A : Type
--   --------------------------
--          Env, A = Defined
checkDef :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
checkDef (SrcPos pos def) = addPos pos $ checkDef def
checkDef (Func f) = checkFn f
checkDef (Resource _name func_list) = forM_ func_list (checkFn . snd)
checkDef (Enum _name _) = return ()
checkDef (Record _name fields) = checkBinders fields
checkDef (TypeAlias _name ty) = checkTy ty
checkDef (Variant _name cases) = forM_ cases (mapM_ checkTy . snd)

checkBinders :: (MonadError CheckError m, MonadState CheckState m) => [(String, Type)] -> m ()
checkBinders = mapM_ (checkTy . snd)

checkFn :: (MonadError CheckError m, MonadState CheckState m) => Function -> m ()
checkFn (Function _name binders result_ty) = do
  collect $ checkBinders binders
  collect $ checkTy result_ty
  bundle

-- check in-use type existed
checkTy :: (MonadError CheckError m, MonadState CheckState m) => Type -> m ()
checkTy (SrcPosType pos ty) = addPos pos $ checkTy ty
-- here, only user type existed is our target to check
checkTy (Defined name) = do
  _ <- lookupEnvironment name
  return ()
checkTy _ = return ()

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
withError :: MonadError e m => (e -> e) -> m a -> m a
withError f action = tryError action >>= either (throwError . f) pure

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
tryError :: MonadError e m => m a -> m (Either e a)
tryError act = (Right <$> act) `catchError` (pure . Left)
