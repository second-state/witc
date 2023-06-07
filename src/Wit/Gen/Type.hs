{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( genTypeDefRust,
    genTypeRust,
  )
where

import Control.Monad.Reader
import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Gen.Normalization
import Wit.TypeValue

genTypeDefRust ::
  MonadReader (M.Map FilePath CheckResult) m =>
  String ->
  TypeVal ->
  m (Doc a)
genTypeDefRust (normalizeIdentifier -> name) = \case
  TyRecord fields -> do
    fields' <-
      forM
        fields
        ( \(n, ty) -> do
            b <- genTypeRust ty
            return $ hsep [pretty n, pretty ":", b]
        )
    return $
      pretty "#[derive(Serialize, Deserialize, Debug)]"
        <> line
        <> pretty "struct"
        <+> pretty name
        <+> braces
          ( line
              <> indent
                4
                ( vsep $
                    punctuate
                      comma
                      fields'
                )
              <> line
          )
  TySum cases -> do
    cases' <- forM cases genCase
    return $
      pretty "#[derive(Serialize, Deserialize, Debug)]"
        <> line
        <> pretty "enum"
        <+> pretty name
        <+> braces (line <> indent 4 (vsep $ punctuate comma cases') <> line)
    where
      genCase :: MonadReader (M.Map FilePath CheckResult) m => (String, TypeVal) -> m (Doc a)
      genCase (normalizeIdentifier -> n, ty) = do
        b <- boxType ty
        return $ pretty n <> b
      boxType :: MonadReader (M.Map FilePath CheckResult) m => TypeVal -> m (Doc a)
      boxType (TyOptional ty) = do
        b <- boxType ty
        return $ pretty "Option" <> angles b
      boxType (TyList ty) = do
        b <- boxType ty
        return $ pretty "Vec" <> angles b
      boxType (TyExpected a b) = do
        a' <- boxType a
        b' <- boxType b
        return $ pretty "Result" <> angles (a' <> pretty "," <> b')
      boxType (TyTuple []) = return mempty
      boxType (TyTuple ty_list) = do
        tys <- forM ty_list boxType
        return $ parens (hsep $ punctuate comma tys)
      boxType (TyRef (normalizeIdentifier -> n)) =
        if n == name
          then return $ pretty "Box" <> angles (pretty n)
          else return $ pretty n
      boxType ty = genTypeRust ty
  TyEnum cases ->
    return $
      pretty "#[derive(Serialize, Deserialize, Debug)]"
        <> line
        <> pretty "enum"
        <+> pretty name
        <+> braces
          ( line
              <> indent 4 (vsep $ punctuate comma (map (pretty . normalizeIdentifier) cases))
              <> line
          )
  TyExternRef mod_file ty_name -> do
    checked <- ask
    genTypeDefRust ty_name $ (checked M.! mod_file).tyEnv M.! ty_name
  ty -> do
    b <- genTypeRust ty
    return $ pretty "type" <+> pretty name <+> pretty "=" <+> b <> pretty ";"

genTypeRust :: MonadReader (M.Map FilePath CheckResult) m => TypeVal -> m (Doc a)
genTypeRust = \case
  TyString -> return $ pretty "String"
  TyUnit -> return $ pretty "()"
  TyU8 -> return $ pretty "u8"
  TyU16 -> return $ pretty "u16"
  TyU32 -> return $ pretty "u32"
  TyU64 -> return $ pretty "u64"
  TyI8 -> return $ pretty "i8"
  TyI16 -> return $ pretty "i16"
  TyI32 -> return $ pretty "i32"
  TyI64 -> return $ pretty "i64"
  TyChar -> return $ pretty "char"
  TyF32 -> return $ pretty "f32"
  TyF64 -> return $ pretty "f64"
  TyOptional ty -> do
    b <- genTypeRust ty
    return $ pretty "Option" <> angles b
  TyList ty -> do
    b <- genTypeRust ty
    return $ pretty "Vec" <> angles b
  TyExpected a b -> do
    a' <- genTypeRust a
    b' <- genTypeRust b
    return $ pretty "Result" <> angles (a' <> pretty "," <> b')
  TyTuple [] -> return mempty
  TyTuple ty_list -> do
    tys <- forM ty_list genTypeRust
    return $ parens (hsep $ punctuate comma tys)
  TyRef (normalizeIdentifier -> name) -> return $ pretty name
  TyExternRef _ (normalizeIdentifier -> ty_name) -> return $ pretty ty_name
  _ -> error "crash type"
