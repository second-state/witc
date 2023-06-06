module Wit.Gen.Import
  ( prettyDefWrap,
    prettyDefExtern,
    toVmWrapper,
  )
where

import Prettyprinter
import Wit.Gen.Normalization
import Wit.Gen.Type
import Wit.TypeValue

-- runtime
toVmWrapper :: String -> String -> TypeSig -> Doc a
toVmWrapper importName name (TyArrow param_list result_ty) =
  hsep
    [ pretty "fn",
      pretty $ normalizeIdentifier name,
      tupled $ pretty "vm: &wasmedge_sdk::Vm" : map (\(p, ty) -> pretty p <+> pretty ":" <+> genTypeRust ty) param_list,
      pretty "->",
      genTypeRust result_ty
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
  where
    sendArgument :: (String, TypeVal) -> Doc a
    sendArgument (param_name, _) =
      pretty $
        "unsafe { witc_abi::runtime::STATE.put_buffer(id, serde_json::to_string(&"
          ++ param_name
          ++ ").unwrap()); }"

-- instance
prettyDefWrap :: String -> TypeSig -> Doc a
prettyDefWrap name (TyArrow param_list result_ty) =
  pretty "fn"
    <+> pretty (normalizeIdentifier name)
      <> parens (hsep $ punctuate comma (map prettyBinder param_list))
    <+> pretty "->"
    <+> genTypeRust result_ty
    <+> braces
      ( pretty "unsafe"
          <> braces
            ( line
                <> indent
                  4
                  ( -- require queue
                    pretty
                      "let id = witc_abi::instance::require_queue();"
                      <> line'
                      <> hsep (map sendArgument param_list)
                      <> line'
                      <> pretty (externalConvention name ++ "(id);")
                      <> line'
                      <> pretty "let mut returns: Vec<String> = vec![];"
                      <> line'
                      <> pretty "serde_json::from_str(witc_abi::instance::read(id).to_string().as_str()).unwrap()"
                  )
                <> line
            )
      )
  where
    sendArgument :: (String, TypeVal) -> Doc a
    sendArgument (param_name, _) =
      pretty
        ("let r = serde_json::to_string(&" ++ param_name ++ ").unwrap();")
        <> line'
        <> pretty "witc_abi::instance::write(id, r.as_ptr() as usize, r.len());"

    prettyBinder :: (String, TypeVal) -> Doc a
    prettyBinder (field_name, ty) = pretty field_name <> pretty ":" <+> genTypeRust ty

prettyDefExtern :: String -> TypeSig -> Doc a
prettyDefExtern (externalConvention -> name) (TyArrow {}) =
  pretty "fn" <+> pretty name <> pretty "(id: i32);"
