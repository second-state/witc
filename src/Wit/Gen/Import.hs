module Wit.Gen.Import
  ( prettyDefWrap,
    prettyDefExtern,
    isTypeDef,
  )
where

import Prettyprinter
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

prettyDefWrap :: Definition -> Doc a
prettyDefWrap (SrcPos _ d) = prettyDefWrap d
prettyDefWrap (Resource _ _) = undefined
prettyDefWrap (Func (Function _attr name param_list result_ty)) =
  hsep (map pretty ["fn", normalizeIdentifier name])
    <+> parens (hsep $ punctuate comma (map prettyBinder param_list))
    <+> hsep [pretty "->", prettyType result_ty]
    <+> braces
      ( -- unsafe call extern function
        hsep
          [ pretty $ "unsafe { extern_" ++ normalizeIdentifier name,
            pretty "(",
            hsep $ punctuate comma (map (paramInto . fst) param_list),
            pretty ") }.into()"
          ]
      )
  where
    paramInto :: String -> Doc a
    paramInto s = pretty $ s ++ ".into()"

    prettyBinder :: (String, Type) -> Doc a
    prettyBinder (field_name, ty) = hsep [pretty field_name, pretty ":", prettyType ty]
prettyDefWrap d = error "should not get type definition here: " $ show d

-- TODO: should be all string pair
prettyDefExtern :: Definition -> Doc a
prettyDefExtern (SrcPos _ d) = prettyDefExtern d
prettyDefExtern (Resource _name _) = undefined
prettyDefExtern (Func (Function _attr name param_list _)) =
  hsep (map pretty ["fn", externalConvention name])
    <+> parens (hsep $ punctuate comma (map (prettyBinder . fst) param_list))
    <+> pretty "->"
    <+> pretty "(usize, usize)"
    <+> pretty ";"
  where
    prettyBinder :: String -> Doc a
    prettyBinder field_name = hsep [pretty field_name, pretty ": (usize, usize)"]
prettyDefExtern d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
