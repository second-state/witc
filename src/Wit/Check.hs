module Wit.Check
  ( check0,
  )
where

import Text.Megaparsec
import Wit.Ast

type M = Either (String, Maybe SourcePos)

report :: String -> M a
report msg = Left (msg, Nothing)

addPos :: SourcePos -> M a -> M a
addPos pos ma = case ma of
  Left (msg, Nothing) -> Left (msg, Just pos)
  ma' -> ma'

type Name = String

type Context = [(Name, Type)]

check0 :: WitFile -> M ()
check0 = check []

check :: Context -> WitFile -> M ()
check ctx wit_file = do
  checkDefinitions ctx $ definition_list wit_file

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
    checkBinders ctx' bs = mapM_ (checkTy ctx . snd) bs
    checkTyList :: Context -> [Type] -> M ()
    checkTyList ctx' = mapM_ (checkTy ctx')

-- check if type is valid
checkTy :: Context -> Type -> M ()
-- here, only user type existed is our target to check
checkTy ctx (User name) = case lookup name ctx of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()
