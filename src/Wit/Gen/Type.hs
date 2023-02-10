{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( prettyTypeDef,
    prettyType,
  )
where

import Prettyprinter
import Wit.Ast
import Wit.Gen.Normalization

prettyTypeDef :: Definition -> Doc a
prettyTypeDef (SrcPos _ d) = prettyTypeDef d
prettyTypeDef (Record (normalizeIdentifier -> name) fields) =
  (pretty "#[derive(Serialize, Deserialize, Debug)]" <+> line)
    <+> pretty "struct"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map prettyField fields))
          <+> line
      )
  where
    prettyField :: (String, Type) -> Doc a
    prettyField (n, ty) = hsep [pretty n, pretty ":", prettyType ty]
prettyTypeDef (TypeAlias (normalizeIdentifier -> name) ty) = hsep [pretty "type", pretty name, pretty "=", prettyType ty, pretty ";"]
prettyTypeDef (Variant (normalizeIdentifier -> name) cases) =
  (pretty "#[derive(Serialize, Deserialize, Debug)]" <+> line)
    <+> pretty "enum"
    <+> pretty name
    <+> braces (line <+> indent 4 (vsep $ punctuate comma (map prettyCase cases)) <+> line)
  where
    prettyCase :: (String, [Type]) -> Doc a
    prettyCase (normalizeIdentifier -> n, []) = pretty n
    prettyCase (normalizeIdentifier -> n, tys) = pretty n <+> parens (hsep (punctuate comma (map boxType tys)))
    boxType :: Type -> Doc a
    boxType (SrcPosType _ t) = boxType t
    boxType (User n) | n == name = pretty $ "Box<" ++ n ++ ">"
    boxType t = prettyType t
prettyTypeDef (Enum (normalizeIdentifier -> name) cases) =
  (pretty "#[derive(Serialize, Deserialize, Debug)]" <+> line)
    <+> pretty "enum"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map pretty cases))
          <+> line
      )
prettyTypeDef _ = error "not a type definition"

prettyType :: Type -> Doc a
prettyType (SrcPosType _ ty) = prettyType ty
prettyType PrimUnit = pretty "()"
prettyType PrimString = pretty "String"
prettyType PrimU8 = pretty "u8"
prettyType PrimU16 = pretty "u16"
prettyType PrimU32 = pretty "u32"
prettyType PrimU64 = pretty "u64"
prettyType PrimI8 = pretty "i8"
prettyType PrimI16 = pretty "i16"
prettyType PrimI32 = pretty "i32"
prettyType PrimI64 = pretty "i64"
prettyType PrimChar = pretty "char"
prettyType PrimF32 = pretty "f32"
prettyType PrimF64 = pretty "f64"
prettyType (Optional ty) = hsep [pretty "Option<", prettyType ty, pretty ">"]
prettyType (ListTy ty) = hsep [pretty "Vec<", prettyType ty, pretty ">"]
prettyType (ExpectedTy ty ety) =
  hsep [pretty "Result<", prettyType ty, pretty ",", prettyType ety, pretty ">"]
prettyType (TupleTy ty_list) = parens (hsep $ punctuate comma (map prettyType ty_list))
prettyType (User (normalizeIdentifier -> name)) = pretty name
prettyType _ = error "impossible"
