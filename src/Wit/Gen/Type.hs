{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( genTypeDefs,
    genTypeRust,
  )
where

import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Gen.Normalization
import Wit.TypeValue

genTypeDefs :: TyEnv -> Doc a
genTypeDefs env =
  let f acc x = acc <> line <> x
   in M.foldl f mempty (M.mapWithKey genTypeDefRust env)

genTypeDefRust :: String -> TypeVal -> Doc a
genTypeDefRust (normalizeIdentifier -> name) = \case
  TyRecord fields ->
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
                    ( map
                        (\(n, ty) -> hsep [pretty n, pretty ":", genTypeRust ty])
                        fields
                    )
              )
            <> line
        )
  TySum cases ->
    pretty "#[derive(Serialize, Deserialize, Debug)]"
      <> line
      <> pretty "enum"
      <+> pretty name
      <+> braces (line <+> indent 4 (vsep $ punctuate comma (map genCase cases)) <+> line)
    where
      genCase :: (String, TypeVal) -> Doc a
      genCase (normalizeIdentifier -> n, ty) = pretty n <> genTypeRust ty
  TyEnum cases ->
    pretty "#[derive(Serialize, Deserialize, Debug)]"
      <> line
      <> pretty "enum"
      <+> pretty name
      <+> braces
        ( line
            <+> indent 4 (vsep $ punctuate comma (map (pretty . normalizeIdentifier) cases))
            <+> line
        )
  ty -> pretty "type" <+> pretty name <+> pretty "=" <+> genTypeRust ty <> pretty ";"

genTypeRust :: TypeVal -> Doc a
genTypeRust = \case
  TyString -> pretty "String"
  TyUnit -> pretty "()"
  TyU8 -> pretty "u8"
  TyU16 -> pretty "u16"
  TyU32 -> pretty "u32"
  TyU64 -> pretty "u64"
  TyI8 -> pretty "i8"
  TyI16 -> pretty "i16"
  TyI32 -> pretty "i32"
  TyI64 -> pretty "i64"
  TyChar -> pretty "char"
  TyF32 -> pretty "f32"
  TyF64 -> pretty "f64"
  (TyOptional ty) -> pretty "Option<" <> genTypeRust ty <> pretty ">"
  (TyList ty) -> pretty "Vec<" <> genTypeRust ty <> pretty ">"
  (TyExpected a b) -> pretty "Result" <> pretty "<" <> genTypeRust a <> pretty "," <> genTypeRust b <> pretty ">"
  (TyTuple ty_list) -> parens (hsep $ punctuate comma (map genTypeRust ty_list))
  (TyRef (normalizeIdentifier -> name)) -> pretty name
  _ -> error "crash type"
