module Wit.Check (check0) where

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
  checkTypeDefList ctx wit_file.type_definition_list

checkTypeDefList :: Context -> [TypeDefinition] -> M ()
checkTypeDefList _ctx [] = return ()
checkTypeDefList ctx (x : xs) = do
  new_ctx <- checkTypeDef ctx x
  checkTypeDefList new_ctx xs

-- insert type definition into Context
-- e.g.
--   Ctx |- check `record A { ... }`
--   -------------------------------
--          (A, User) : Ctx
checkTypeDef :: Context -> TypeDefinition -> M Context
checkTypeDef ctx = \case
  SrcPos pos tydef -> addPos pos $ checkTypeDef ctx tydef
  Record name fields -> do
    mapM_ (checkTy ctx . snd) fields
    return $ (name, User name) : ctx
  TypeAlias name ty -> do
    checkTy ctx ty
    return $ (name, User name) : ctx
  Variant name cases -> do
    mapM_ (checkTyList ctx . snd) cases
    return $ (name, User name) : ctx
  where
    checkTyList :: Context -> [Type] -> M ()
    checkTyList ctx' = mapM_ (checkTy ctx')

-- check if type is valid
checkTy :: Context -> Type -> M ()
-- here, only user type existed is our target to check
checkTy ctx (User name) = case lookup name ctx of
  Just _ -> return ()
  Nothing -> report $ "Type `" ++ name ++ "` not found"
checkTy _ _ = return ()
