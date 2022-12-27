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

check0 :: WitFile -> IO (M (WitFile, Env))
check0 = check []

check :: Env -> WitFile -> IO (M (WitFile, Env))
check ctx wit_file = do
  mapM_ checkUseFileExisted $ use_list wit_file
  case introUseIdentifiers ctx $ use_list wit_file of
    Left e -> return $ Left e
    Right env -> do
      case foldM checkDef env $ definition_list wit_file of
        Left e -> return $ Left e
        Right env' -> return $ Right (wit_file, env')

introUseIdentifiers :: Env -> [Use] -> M Env
introUseIdentifiers ctx = \case
  [] -> return ctx
  (u : us) -> introUseIdentifiers (ctx `extend` u) us
  where
    extend :: Env -> Use -> Env
    extend env' = \case
      (SrcPosUse _pos u) -> env' `extend` u
      (Use imports _) ->
        foldl
          (\env'' name -> (name, User name) : env'')
          env'
          imports
      (UseAll _) -> env'

checkUseFileExisted :: Use -> IO (M ())
checkUseFileExisted (SrcPosUse pos u) = do
  a <- checkUseFileExisted u
  return $ addPos pos a
-- TODO: check imports should exist in that module
checkUseFileExisted (Use _imports mod_name) = checkModFileExisted mod_name
checkUseFileExisted (UseAll mod_name) = checkModFileExisted mod_name

checkModFileExisted :: String -> IO (M ())
-- fileExist
checkModFileExisted mod_name = do
  existed <- doesFileExist $ mod_name ++ ".wit"
  if existed then return (Right ()) else return $ report "no file xxx"

-- insert type definition into Env
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkDef :: Env -> Definition -> M Env
checkDef env = \case
  SrcPos pos def -> addPos pos $ checkDef env def
  Func (Function _attr _name binders result_ty) -> do
    checkBinders env binders
    checkTy env result_ty
    return env
  Resource _name _func_list -> error "unimplemented"
  Enum name _ -> return $ (name, PrimU32) : env
  Record name fields -> do
    checkBinders env fields
    return $ (name, TupleTy $ map snd fields) : env
  TypeAlias name ty -> do
    checkTy env ty
    return $ (name, ty) : env
  Variant name cases -> do
    let env' = (name, VSum name $ map (TupleTy . snd) cases) : env
    -- as a sum of product, it's ok to be defined recursively
    mapM_ (checkTyList env' . snd) cases
    return env'
  where
    checkBinders :: Env -> [(String, Type)] -> M ()
    checkBinders ctx' = mapM_ (checkTy ctx' . snd)
    checkTyList :: Env -> [Type] -> M ()
    checkTyList ctx' = mapM_ (checkTy ctx')

-- check if type is valid
checkTy :: Env -> Type -> M ()
checkTy env (SrcPosType pos ty) = addPos pos $ checkTy env ty
-- here, only user type existed is our target to check
checkTy env (User name) = case lookupEnv name env of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()
