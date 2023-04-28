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
        ( hsep
            ( [pretty "let id = unsafe { STATE.new_queue() }; "]
                ++ map sendArgument param_list
                ++ [ pretty "serde_json::from_str(unsafe { STATE.read_buffer(id).as_str() }).unwrap()"
                   ]
            )
        )
  d -> error "should not get this definition here: " $ show d
  where
    sendArgument :: (String, Type) -> Doc a
    sendArgument (param_name, _) =
      hsep $
        map
          pretty
          [ "let r = serde_json::to_string(&" ++ param_name ++ ").unwrap();",
            "unsafe { STATE.put_buffer(id, r); }"
          ]

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
