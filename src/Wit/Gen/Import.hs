module Wit.Gen.Import
  ( prettyDefWrap,
    prettyDefExtern,
    toVmWrapper,
  )
where

import Prettyprinter
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

-- runtime
toVmWrapper :: String -> Definition -> Doc a
toVmWrapper importName = \case
  (SrcPos _ d) -> toVmWrapper importName d
  (Func (Function (normalizeIdentifier -> name) param_list result_ty)) ->
    hsep
      [ pretty "fn",
        pretty name,
        tupled $ pretty "vm: &wasmedge_sdk::Vm" : map (\(p, ty) -> pretty p <+> pretty ":" <+> prettyType ty) param_list,
        pretty "->",
        prettyType result_ty
      ]
      <+> braces
        ( vsep
            ( [ pretty "let cfg = CallingConfig::new" <+> tupled [pretty "vm", dquotes $ pretty importName] <+> pretty ";",
                pretty "let mut args = vec![];"
              ]
                ++ map
                  (\(p, _) -> pretty "let mut a = cfg.put_to_remote" <+> parens (pretty "&" <+> pretty p) <+> pretty ";" <+> pretty "args.append(&mut a);")
                  param_list
                ++ [ pretty "let r = cfg.run" <+> tupled [dquotes $ pretty $ externalConvention name, pretty "args"] <+> pretty ";",
                     pretty "let result_len = r[1].to_i32() as usize;",
                     pretty "let mut s = String::with_capacity(result_len);",
                     pretty "cfg.read_from_remote(&mut s, r[0], result_len)"
                   ]
            )
        )
  d -> error "should not get this definition here: " $ show d

-- instance
prettyDefWrap :: Definition -> Doc a
prettyDefWrap (SrcPos _ d) = prettyDefWrap d
prettyDefWrap (Func (Function name param_list result_ty)) =
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
prettyDefExtern (Func (Function name param_list _)) =
  hsep (map pretty ["fn", externalConvention name])
    <+> parens (hsep $ punctuate comma (map (prettyBinder . fst) param_list))
    <+> pretty "->"
    <+> pretty "(usize, usize)"
    <+> pretty ";"
  where
    prettyBinder :: String -> Doc a
    prettyBinder field_name = hsep [pretty field_name, pretty ": (usize, usize)"]
prettyDefExtern d = error "should not get type definition here: " $ show d
