module Wit.Gen.Import
  ( prettyDefWrap,
    prettyDefExtern,
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
        pretty "let s = "
          <+> hsep
            [ pretty $ "from_remote_string (unsafe { extern_" ++ normalizeIdentifier name,
              parens $
                hsep $
                  punctuate comma (map (paramInto . fst) param_list),
              pretty "});"
            ]
          <+> pretty "serde_json::from_str(s.as_str()).unwrap()"
      )
  where
    paramInto :: String -> Doc a
    paramInto s = pretty "as_remote_string" <+> parens (pretty s)

    prettyBinder :: (String, Type) -> Doc a
    prettyBinder (field_name, ty) = hsep [pretty field_name, pretty ":", prettyType ty]
prettyDefWrap d = error "should not get type definition here: " $ show d

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
