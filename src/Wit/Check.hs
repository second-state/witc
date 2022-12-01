module Wit.Check
  ( CheckError,
    check0,
  )
where

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

type Context = [(Name, Type)]

check0 :: WitFile -> IO (M WitFile)
check0 = check []

check :: Context -> WitFile -> IO (M WitFile)
check ctx wit_file = do
  mapM_ checkUseFileExisted $ use_list wit_file
  case introUseIdentifiers ctx $ use_list wit_file of
    Left e -> return $ Left e
    Right c -> do
      case checkDefinitions c $ definition_list wit_file of
        Left e -> return $ Left e
        Right () -> return $ Right wit_file

introUseIdentifiers :: Context -> [Use] -> M Context
introUseIdentifiers ctx = \case
  [] -> return ctx
  (u : us) -> introUseIdentifiers (ctx `extend` u) us
  where
    extend :: Context -> Use -> Context
    extend ctx' = \case
      (SrcPosUse _pos u) -> ctx' `extend` u
      (Use imports _) -> foldl (\c x -> (x, User x) : c) ctx' imports
      (UseAll _) -> ctx'

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

checkDefinitions :: Context -> [Definition] -> M ()
checkDefinitions _ctx [] = return ()
checkDefinitions ctx (x : xs) = do
  new_ctx <- checkDef ctx x
  checkDefinitions new_ctx xs

-- insert type definition into Context
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkDef :: Context -> Definition -> M Context
checkDef ctx = \case
  SrcPos pos def -> addPos pos $ checkDef ctx def
  Func (Function _attr _name binders result_ty) -> do
    checkBinders ctx binders
    checkTy ctx result_ty
    return ctx
  Resource _name _func_list -> error "unimplemented"
  Enum name _ -> return $ (name, User name) : ctx
  Record name fields -> do
    checkBinders ctx fields
    return $ (name, User name) : ctx
  TypeAlias name ty -> do
    checkTy ctx ty
    return $ (name, User name) : ctx
  Variant name cases -> do
    mapM_ (checkTyList ctx . snd) cases
    return $ (name, User name) : ctx
  where
    checkBinders :: Context -> [(String, Type)] -> M ()
    checkBinders ctx' = mapM_ (checkTy ctx' . snd)
    checkTyList :: Context -> [Type] -> M ()
    checkTyList ctx' = mapM_ (checkTy ctx')

-- check if type is valid
checkTy :: Context -> Type -> M ()
checkTy ctx (SrcPosType pos ty) = addPos pos $ checkTy ctx ty
-- here, only user type existed is our target to check
checkTy ctx (User name) = case lookup name ctx of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()
