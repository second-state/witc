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
      ( pretty
          "unsafe"
          <+> braces
            ( -- require queue
              pretty
                "let id = require_queue();"
                <+> hsep (map sendArgument param_list)
                <+> pretty (externalConvention name ++ "(id);")
                <+> pretty "let mut returns: Vec<String> = vec![];"
                -- NOTE: we must clone the string, because next `read` will reuse this memory block
                -- FIXME: maybe we need to check how many `read` calls are needed?
                <+> pretty "let returns = read(id).to_string().clone();"
                <+> pretty "serde_json::from_str(returns.as_str()).unwrap()"
            )
      )
  where
    sendArgument :: (String, Type) -> Doc a
    sendArgument (param_name, _) =
      hsep $
        map
          pretty
          [ "let r = serde_json::to_string(&" ++ param_name ++ ").unwrap();",
            "write(id, r.as_ptr() as usize, r.len());"
          ]

    prettyBinder :: (String, Type) -> Doc a
    prettyBinder (field_name, ty) = hsep [pretty field_name, pretty ":", prettyType ty]
prettyDefWrap d = error "should not get type definition here: " $ show d

prettyDefExtern :: Definition -> Doc a
prettyDefExtern (SrcPos _ d) = prettyDefExtern d
prettyDefExtern (Func (Function name _ _)) =
  hsep (map pretty ["fn", externalConvention name])
    <+> pretty "(id: i32)"
    <+> pretty ";"
prettyDefExtern d = error "should not get type definition here: " $ show d
