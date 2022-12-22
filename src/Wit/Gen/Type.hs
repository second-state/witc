{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( prettyTypeDef,
    prettyType,
    prettyABIType,
    prettyBinder,
    prettyABIBinder,
  )
where

import Prettyprinter
import Wit.Ast

prettyTypeDef :: Definition -> Doc a
prettyTypeDef (SrcPos _ d) = prettyTypeDef d
prettyTypeDef (Func _) = undefined
prettyTypeDef (Resource _ _) = undefined
prettyTypeDef (Record name fields) =
  pretty "#[repr(C)]"
    <+> line
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
prettyTypeDef (TypeAlias name ty) = hsep [pretty "type", pretty name, pretty "=", prettyType ty, pretty ";"]
prettyTypeDef (Variant name cases) =
  pretty "#[repr(C, u32)]"
    <+> line
    <+> pretty "enum"
    <+> pretty name
    <+> braces (line <+> indent 4 (vsep $ punctuate comma (map prettyCase cases)) <+> line)
  where
    prettyCase :: (String, [Type]) -> Doc a
    prettyCase (n, []) = pretty n
    prettyCase (n, tys) = pretty n <+> parens (hsep (punctuate comma (map boxType tys)))
    boxType :: Type -> Doc a
    boxType (SrcPosType _ t) = boxType t
    boxType (User n) =
      if n == name
        then pretty $ "Box<" ++ n ++ ">"
        else pretty n
    boxType t = prettyType t
prettyTypeDef (Enum name cases) =
  pretty "#[repr(C, u32)]"
    <+> line
    <+> pretty "enum"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map pretty cases))
          <+> line
      )

prettyBinder :: (String, Type) -> Doc a
prettyBinder (field_name, ty) = hsep [pretty field_name, pretty ":", prettyType ty]

prettyABIBinder :: (String, Type) -> Doc a
prettyABIBinder (field_name, ty) = hsep [pretty field_name, pretty ":", prettyABIType ty]

prettyType :: Type -> Doc a
prettyType (SrcPosType _ ty) = prettyType ty
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
prettyType (User name) = pretty name

prettyABIType :: Type -> Doc a
prettyABIType (SrcPosType _ ty) = prettyABIType ty
prettyABIType PrimString = pretty "WitString"
prettyABIType (Optional ty) = hsep [pretty "WitOption<", prettyABIType ty, pretty ">"]
prettyABIType (ListTy ty) = hsep [pretty "WitVec<", prettyABIType ty, pretty ">"]
prettyABIType (ExpectedTy ty ety) =
  hsep [pretty "WitResult<", prettyType ty, pretty ",", prettyType ety, pretty ">"]
prettyABIType ty = prettyType ty
