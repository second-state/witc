module Wit.Gen.Plugin
  ( convertFuncRust,
  )
where

import Prettyprinter
import Wit.Ast
import Wit.Gen.Normalization

convertFuncRust :: String -> Definition -> Doc a
convertFuncRust pluginName = \case
  (SrcPos _ def) -> convertFuncRust pluginName def
  (Func (Function (normalizeIdentifier -> name) param_list result_ty)) ->
    pretty "#[link_name ="
      <+> dquotes (pretty $ pluginName ++ "_" ++ name)
        <> pretty "]"
      <+> line'
        <> pretty
          "pub"
      <+> pretty "fn"
      <+> pretty name
        <> parens (hsep (punctuate comma (map convertParamRust param_list)))
      <+> pretty "->"
      <+> convertTyRust result_ty
        <> semi
  _ -> mempty
  where
    convertPtrTypeRust paramName =
      pretty (paramName ++ "_ptr")
        <> colon
        <+> pretty "*const u8"
          <> comma
        <+> pretty (paramName ++ "_len")
          <> colon
        <+> pretty "usize"

    convertParamRust (normalizeIdentifier -> paramName, ty) =
      case force ty of
        -- string & list can be converted to a pointer and a size
        PrimString -> convertPtrTypeRust paramName
        ListTy _ -> convertPtrTypeRust paramName
        _ -> pretty paramName <> colon <+> convertTyRust ty

force :: Type -> Type
force (SrcPosType _ ty) = force ty
force ty = ty

convertTyRust :: Type -> Doc a
convertTyRust (SrcPosType _ ty) = convertTyRust ty
convertTyRust PrimUnit = pretty "()"
convertTyRust PrimU8 = pretty "u8"
convertTyRust PrimU16 = pretty "u16"
convertTyRust PrimU32 = pretty "u32"
convertTyRust PrimU64 = pretty "u64"
convertTyRust PrimI8 = pretty "i8"
convertTyRust PrimI16 = pretty "i16"
convertTyRust PrimI32 = pretty "i32"
convertTyRust PrimI64 = pretty "i64"
convertTyRust PrimChar = pretty "char"
convertTyRust PrimF32 = pretty "f32"
convertTyRust PrimF64 = pretty "f64"
convertTyRust ty = error $ "no support " ++ show ty ++ " when generating plugin"
