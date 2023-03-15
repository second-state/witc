module Wit.Check
  ( CheckError (..),
    parseFile,
    checkFile,
    check0,
    eitherIO,
    Env,
    lookupEnv,
  )
where

import Control.Monad
import Data.Maybe
import System.Directory
import System.Exit (exitSuccess)
import Text.Megaparsec
import Wit.Ast
import Wit.Parser (ParserError, pWitFile)

data CheckError
  = CheckError String (Maybe SourcePos)
  | PErr ParserError

instance Show CheckError where
  show (PErr bundle) = errorBundlePretty bundle
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

parseFile :: FilePath -> IO (Either CheckError WitFile)
parseFile filepath = do
  content <- readFile filepath
  case parse pWitFile filepath content of
    Left e -> return $ Left (PErr e)
    Right ast -> return $ Right ast

checkFile :: FilePath -> IO WitFile
checkFile = parseFile >=> eitherIO (check0 >=> eitherIO return)

eitherIO :: Show e => (a -> IO b) -> Either e a -> IO b
eitherIO f = \case
  Left e -> print e *> exitSuccess
  Right a -> f a

check0 :: WitFile -> IO (M WitFile)
check0 = check []

check :: Env -> WitFile -> IO (M WitFile)
check ctx wit_file = do
  results <- mapM checkUseFileExisted $ use_list wit_file
  case sequence results of
    Left e -> return $ Left e
    Right _ ->
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
checkModFileExisted requires mod_name = do
  let module_file = mod_name ++ ".wit"
  -- first ensure file exist
  existed <- doesFileExist module_file
  if existed
    then do
      -- and this ensure checking recursively
      m <- checkFile module_file
      results <- forM requires $ ensure_require (mapMaybe collect_type_name m.definition_list)
      case sequence results of
        Left e -> return $ Left e
        Right _ -> return $ Right ()
    else return $ report $ "no file " ++ module_file
  where
    ensure_require :: [String] -> String -> IO (M ())
    ensure_require types req = do
      if req `elem` types
        then return $ Right ()
        else return $ report $ "no type " ++ req ++ " in module " ++ mod_name

    collect_type_name :: Definition -> Maybe String
    collect_type_name (SrcPos _ d) = collect_type_name d
    collect_type_name (Resource name _) = Just name
    collect_type_name (Enum name _) = Just name
    collect_type_name (Record name _) = Just name
    collect_type_name (TypeAlias name _) = Just name
    collect_type_name (Variant name _) = Just name
    collect_type_name (Func _) = Nothing

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
