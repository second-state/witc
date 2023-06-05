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
        ( indent
            4
            ( vsep
                ( [pretty "let id = unsafe { witc_abi::runtime::STATE.new_queue() }; "]
                    ++ map sendArgument param_list
                    ++ [ hsep
                           [ pretty "vm.run_func(Some(",
                             dquotes (pretty importName),
                             pretty "), ",
                             dquotes (pretty $ externalConvention name),
                             pretty ", vec![wasmedge_sdk::WasmValue::from_i32(id)]).unwrap();"
                           ],
                         pretty "serde_json::from_str(unsafe { witc_abi::runtime::STATE.read_buffer(id).as_str() }).unwrap()"
                       ]
                )
            )
        )
  d -> error "should not get this definition here: " $ show d
  where
    sendArgument :: (String, Type) -> Doc a
    sendArgument (param_name, _) =
      pretty $
        "unsafe { witc_abi::runtime::STATE.put_buffer(id, serde_json::to_string(&"
          ++ param_name
          ++ ").unwrap()); }"

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
                "let id = witc_abi::instance::require_queue();"
                <+> hsep (map sendArgument param_list)
                <+> pretty (externalConvention name ++ "(id);")
                <+> pretty "let mut returns: Vec<String> = vec![];"
                <+> pretty "serde_json::from_str(witc_abi::instance::read(id).to_string().as_str()).unwrap()"
            )
      )
  where
    sendArgument :: (String, Type) -> Doc a
    sendArgument (param_name, _) =
      hsep $
        map
          pretty
          [ "let r = serde_json::to_string(&" ++ param_name ++ ").unwrap();",
            "witc_abi::instance::write(id, r.as_ptr() as usize, r.len());"
          ]

    prettyBinder :: (String, Type) -> Doc a
    prettyBinder (field_name, ty) = hsep [pretty field_name, pretty ":", genTypeRust ty]
prettyDefWrap d = error "should not get type definition here: " $ show d

prettyDefExtern :: Definition -> Doc a
prettyDefExtern (SrcPos _ d) = prettyDefExtern d
prettyDefExtern (Func (Function name _ _)) =
  hsep (map pretty ["fn", externalConvention name])
    <+> pretty "(id: i32)"
    <+> pretty ";"
prettyDefExtern d = error "should not get type definition here: " $ show d
