module Wit.Gen.Plugin
  ( convertFuncRust,
  )
where

import Control.Monad.Reader
import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Gen.Normalization
import Wit.TypeValue

convertFuncRust :: MonadReader (M.Map FilePath CheckResult) m => String -> String -> TypeSig -> m (Doc a)
convertFuncRust pluginName (normalizeIdentifier -> name) (TyArrow param_list result_ty) =
  return $
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
      case ty of
        -- string & list can be converted to a pointer and a size
        TyString -> convertPtrTypeRust paramName
        TyList _ -> convertPtrTypeRust paramName
        _ -> pretty paramName <> colon <+> convertTyRust ty

convertTyRust :: TypeVal -> Doc a
convertTyRust TyUnit = pretty "()"
convertTyRust TyU8 = pretty "u8"
convertTyRust TyU16 = pretty "u16"
convertTyRust TyU32 = pretty "u32"
convertTyRust TyU64 = pretty "u64"
convertTyRust TyI8 = pretty "i8"
convertTyRust TyI16 = pretty "i16"
convertTyRust TyI32 = pretty "i32"
convertTyRust TyI64 = pretty "i64"
convertTyRust TyChar = pretty "char"
convertTyRust TyF32 = pretty "f32"
convertTyRust TyF64 = pretty "f64"
convertTyRust (TyRef (normalizeIdentifier -> name)) = pretty name
convertTyRust _ = error "unsupported type occurs when generating plugin"
