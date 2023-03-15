module Wit.Check
  ( CheckError,
    check0,
    Env,
    lookupEnv,
  )
where

import Control.Monad
import System.Directory
import Text.Megaparsec
import Wit.Ast

data CheckError = CheckError String (Maybe SourcePos)

instance Show CheckError where
  show (CheckError msg (Just pos)) = sourcePosPretty pos ++ ": " ++ msg
  show (CheckError msg Nothing) = msg

type M = Either CheckError

report :: String -> M a
report msg = Left $ CheckError msg Nothing

addPos :: SourcePos -> M a -> M a
addPos pos ma = case ma of
  Left (CheckError msg Nothing) -> Left (CheckError msg (Just pos))
  ma' -> ma'

type Name = String

type Env = [(Name, Type)]

lookupEnv :: Name -> Env -> Maybe Type
lookupEnv = lookup

check0 :: WitFile -> IO (M WitFile)
check0 = check []

check :: Env -> WitFile -> IO (M WitFile)
check ctx wit_file = do
  mapM_ checkUseFileExisted $ use_list wit_file
  case introUseIdentifiers ctx $ use_list wit_file of
    Left e -> return $ Left e
    Right env -> do
      newEnv <- foldM addTypeDef env $ definition_list wit_file
      case forM (definition_list wit_file) (checkDef newEnv) of
        Left err -> return $ Left err
        Right _ -> return $ Right wit_file

introUseIdentifiers :: Env -> [Use] -> M Env
introUseIdentifiers env = \case
  [] -> return env
  (u : us) -> introUseIdentifiers (env `extend` u) us
  where
    extend :: Env -> Use -> Env
    extend env' = \case
      (SrcPosUse _pos u) -> env' `extend` u
      (Use imports _) -> foldl (\env'' name -> (name, User name) : env'') env' imports
      (UseAll _) -> env'

checkUseFileExisted :: Use -> IO (M ())
checkUseFileExisted (SrcPosUse pos u) = do
  a <- checkUseFileExisted u
  return $ addPos pos a
checkUseFileExisted (Use imports mod_name) = checkModFileExisted imports mod_name
checkUseFileExisted (UseAll mod_name) = checkModFileExisted [] mod_name

checkModFileExisted :: [String] -> String -> IO (M ())
-- fileExist
checkModFileExisted requires mod_name = do
  -- TODO: check requires exist in the module
  -- In fact, we should check modules recursively
  existed <- doesFileExist $ mod_name ++ ".wit"
  if existed then return (Right ()) else return $ report "no file xxx"

addTypeDef :: Env -> Definition -> IO Env
addTypeDef env = \case
  SrcPos _ def -> addTypeDef env def
  Func _ -> return env
  Resource name _ -> return $ (name, User name) : env
  Enum name _ -> return $ (name, PrimU32) : env
  Record name fields -> return $ (name, TupleTy $ map snd fields) : env
  TypeAlias name ty -> return $ (name, ty) : env
  -- as a sum of product, it's ok to be defined recursively
  Variant name cases -> return $ (name, VSum name $ map (TupleTy . snd) cases) : env

-- insert type definition into Env
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkDef :: Env -> Definition -> M ()
checkDef env = \case
  SrcPos pos def -> addPos pos $ checkDef env def
  Func f -> checkFn env f
  Resource _name func_list -> forM_ func_list (checkFn env . snd)
  Enum _name _ -> return ()
  Record _name fields -> checkBinders env fields
  TypeAlias _name ty -> checkTy env ty
  Variant _name cases -> forM_ cases (checkTyList env . snd)
  where
    checkBinders :: Env -> [(String, Type)] -> M ()
    checkBinders env' = mapM_ (checkTy env' . snd)

    checkTyList :: Env -> [Type] -> M ()
    checkTyList env' = mapM_ (checkTy env')

    checkFn :: Env -> Function -> M ()
    checkFn env' (Function _name binders result_ty) = do
      checkBinders env' binders
      checkTy env' result_ty

-- check if type is valid
checkTy :: Env -> Type -> M ()
checkTy env (SrcPosType pos ty) = addPos pos $ checkTy env ty
-- here, only user type existed is our target to check
checkTy env (User name) = case lookupEnv name env of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()
