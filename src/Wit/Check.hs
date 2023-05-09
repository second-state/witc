module Wit.Check
  ( CheckError (..),
    parseFile,
    checkFile,
    check,
    Env,
    lookupEnv,
  )
where

import Control.Monad
import Control.Monad.Except
import Data.Map.Lazy qualified as M
import Data.Maybe
import System.Directory
import Text.Megaparsec
import Wit.Ast
import Wit.Parser (ParserError, pWitFile)
import Prettyprinter

data CheckError
  = CheckError String (Maybe SourcePos)
  | PErr ParserError

instance Pretty CheckError where
  pretty (PErr bundle) = pretty (errorBundlePretty bundle)
  pretty (CheckError msg (Just pos)) = pretty (sourcePosPretty pos) <> colon <+> pretty msg <> line
  pretty (CheckError msg Nothing) = pretty msg <> line

report :: (MonadError CheckError m) => String -> m a
report msg = throwError $ CheckError msg Nothing

addPos :: (MonadError CheckError m) => SourcePos -> m a -> m a
addPos pos = withError updatePos
  where
    updatePos :: CheckError -> CheckError
    updatePos (CheckError msg Nothing) = CheckError msg (Just pos)
    updatePos e = e

type Name = String

type Env = M.Map Name Type

lookupEnv :: Name -> Env -> Maybe Type
lookupEnv = M.lookup

parseFile :: (MonadIO m) => (MonadError CheckError m) => FilePath -> m WitFile
parseFile filepath = do
  content <- liftIO $ readFile filepath
  case parse pWitFile filepath content of
    Left e -> throwError $ PErr e
    Right ast -> return ast

checkFile :: (MonadIO m) => (MonadError CheckError m) => FilePath -> m WitFile
checkFile path = do
  ast <- parseFile path
  check M.empty ast

check :: (MonadIO m) => (MonadError CheckError m) => Env -> WitFile -> m WitFile
check ctx wit_file = do
  mapM_ checkUseFileExisted $ use_list wit_file
  env <- introUseIdentifiers ctx $ use_list wit_file
  newEnv <- foldM addTypeDef env $ definition_list wit_file
  forM_ (definition_list wit_file) (checkDef newEnv)
  return wit_file

introUseIdentifiers :: (MonadError CheckError m) => Env -> [Use] -> m Env
introUseIdentifiers env = \case
  [] -> return env
  (u : us) -> introUseIdentifiers (env `extend` u) us
  where
    extend :: Env -> Use -> Env
    extend env' = \case
      (SrcPosUse _pos u) -> env' `extend` u
      (Use imports _) -> foldl (\env'' name -> M.insert name (User name) env'') env' imports
      (UseAll _) -> env'

checkUseFileExisted :: (MonadIO m) => (MonadError CheckError m) => Use -> m ()
checkUseFileExisted (SrcPosUse pos u) = do
  addPos pos $ checkUseFileExisted u
checkUseFileExisted (Use imports mod_name) = checkModFileExisted imports mod_name
checkUseFileExisted (UseAll mod_name) = checkModFileExisted [] mod_name

checkModFileExisted :: (MonadIO m) => (MonadError CheckError m) => [String] -> String -> m ()
checkModFileExisted requires mod_name = do
  let module_file = mod_name ++ ".wit"
  -- first ensure file exist
  existed <- liftIO $ doesFileExist module_file
  if existed
    then do
      -- checking files recursively
      m <- checkFile module_file
      forM_ requires $ ensureRequire (mapMaybe collectTypeName m.definition_list)
    else report $ "no file " ++ module_file
  where
    -- ensure required types are defined in the imported module
    ensureRequire :: (MonadError CheckError m) => [String] -> String -> m ()
    ensureRequire types req = do
      if req `elem` types
        then return ()
        else report $ "no type " ++ req ++ " in module " ++ mod_name

    collectTypeName :: Definition -> Maybe String
    collectTypeName (SrcPos _ d) = collectTypeName d
    collectTypeName (Resource name _) = Just name
    collectTypeName (Enum name _) = Just name
    collectTypeName (Record name _) = Just name
    collectTypeName (TypeAlias name _) = Just name
    collectTypeName (Variant name _) = Just name
    collectTypeName (Func _) = Nothing

addTypeDef :: (MonadError CheckError m) => Env -> Definition -> m Env
addTypeDef env = \case
  SrcPos _ def -> addTypeDef env def
  Func _ -> return env
  Resource name _ -> return $ M.insert name (User name) env
  Enum name _ -> return $ M.insert name PrimU32 env
  Record name fields -> return $ M.insert name (TupleTy $ map snd fields) env
  TypeAlias name ty -> return $ M.insert name ty env
  -- as a sum of product, it's ok to be defined recursively
  Variant name cases -> return $ M.insert name (VSum name $ map (TupleTy . snd) cases) env

-- insert type definition into Env
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkDef :: (MonadError CheckError m) => Env -> Definition -> m ()
checkDef env = \case
  SrcPos pos def -> addPos pos $ checkDef env def
  Func f -> checkFn env f
  Resource _name func_list -> forM_ func_list (checkFn env . snd)
  Enum _name _ -> return ()
  Record _name fields -> checkBinders env fields
  TypeAlias _name ty -> checkTy env ty
  Variant _name cases -> forM_ cases (checkTyList env . snd)
  where
    checkBinders :: (MonadError CheckError m) => Env -> [(String, Type)] -> m ()
    checkBinders env' = mapM_ (checkTy env' . snd)

    checkTyList :: (MonadError CheckError m) => Env -> [Type] -> m ()
    checkTyList env' = mapM_ (checkTy env')

    checkFn :: (MonadError CheckError m) => Env -> Function -> m ()
    checkFn env' (Function _name binders result_ty) = do
      checkBinders env' binders
      checkTy env' result_ty

-- check if type is valid
checkTy :: (MonadError CheckError m) => Env -> Type -> m ()
checkTy env (SrcPosType pos ty) = addPos pos $ checkTy env ty
-- here, only user type existed is our target to check
checkTy env (User name) = case lookupEnv name env of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
withError :: MonadError e m => (e -> e) -> m a -> m a
withError f action = tryError action >>= either (throwError . f) pure

-- WARNING: port from mtl, once newer mtl is applied, we can remove this
tryError :: MonadError e m => m a -> m (Either e a)
tryError act = (Right <$> act) `catchError` (pure . Left)
