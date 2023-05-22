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
    context :: M.Map Name Type
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

lookupContext :: (MonadState CheckState m) => Name -> m (Maybe Type)
lookupContext name = do
  ctx <- gets context
  return $ M.lookup name ctx

updateContext :: (MonadState CheckState m) => Name -> Type -> m ()
updateContext name ty = do
  s <- get
  put $ s {context = M.insert name ty $ context s}

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
    else report $ "no file `" ++ path ++ "` in `" ++ normalise workingDir ++ "`"

check ::
  (MonadIO m, MonadError CheckError m, MonadState CheckState m, MonadReader FilePath m) =>
  WitFile ->
  m WitFile
check wit_file = do
  forM_ (use_list wit_file) (collect . checkUseFileExisted)
  bundle
  introUseIdentifiers $ use_list wit_file
  forM_ wit_file.definition_list addTypeDef
  forM_ (definition_list wit_file) (collect . checkDef)
  bundle
  return wit_file

introUseIdentifiers :: (MonadState CheckState m) => [Use] -> m ()
introUseIdentifiers us = do
  forM_ us extend
  where
    extend (SrcPosUse _pos u) = extend u
    extend (Use imports _) = do
      forM_ imports $ \(_, name) -> do
        updateContext name (User name)
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

addTypeDef :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
addTypeDef (SrcPos _ def) = addTypeDef def
addTypeDef (Resource name _) = updateContext name (User name)
addTypeDef (Enum name _) = updateContext name PrimU32
addTypeDef (Record name fields) = updateContext name (TupleTy $ map snd fields)
addTypeDef (TypeAlias name ty) = updateContext name ty
-- as a sum of product, it's ok to be defined recursively
addTypeDef (Variant name cases) = updateContext name (VSum name $ map (TupleTy . snd) cases)
addTypeDef (Func _) = return ()

-- insert type definition into Env
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkDef :: (MonadError CheckError m, MonadState CheckState m) => Definition -> m ()
checkDef (SrcPos pos def) = addPos pos $ checkDef def
checkDef (Func f) = checkFn f
checkDef (Resource _name func_list) = forM_ func_list (checkFn . snd)
checkDef (Enum _name _) = return ()
checkDef (Record _name fields) = checkBinders fields
checkDef (TypeAlias _name ty) = checkTy ty
checkDef (Variant _name cases) = forM_ cases (checkTyList . snd)

checkBinders :: (MonadError CheckError m, MonadState CheckState m) => [(String, Type)] -> m ()
checkBinders = mapM_ (checkTy . snd)

checkTyList :: (MonadError CheckError m, MonadState CheckState m) => [Type] -> m ()
checkTyList = mapM_ checkTy

checkFn :: (MonadError CheckError m, MonadState CheckState m) => Function -> m ()
checkFn (Function _name binders result_ty) = do
  checkBinders binders
  checkTy result_ty

-- check if type is valid
checkTy :: (MonadError CheckError m, MonadState CheckState m) => Type -> m ()
checkTy (SrcPosType pos ty) = addPos pos $ checkTy ty
-- here, only user type existed is our target to check
checkTy (User name) = do
  r <- lookupContext name
  case r of
    Just _ -> return ()
    Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ = return ()

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
withError :: MonadError e m => (e -> e) -> m a -> m a
withError f action = tryError action >>= either (throwError . f) pure

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
tryError :: MonadError e m => m a -> m (Either e a)
tryError act = (Right <$> act) `catchError` (pure . Left)
