module Wit.Gen.Export
  ( witObject,
    toHostFunction,
    toUnsafeExtern,
  )
where

import Prettyprinter
import Wit.Gen.Normalization
import Wit.Gen.Type
import Wit.TypeValue

-- instance
toUnsafeExtern :: String -> TypeSig -> Doc a
toUnsafeExtern name (TyArrow param_list _result_ty) =
  vsep
    [ pretty "#[no_mangle]",
      pretty "pub unsafe extern \"C\"",
      hsep
        [ pretty "fn",
          pretty $ externalConvention name,
          parens $ pretty "id: i32"
        ],
      braces
        ( indent
            4
            ( vsep $
                map getParameter param_list
                  ++ [ pretty "let r ="
                         <+> pretty (normalizeIdentifier name)
                         <+> tupled (map (\(x, _) -> pretty x) param_list)
                         <+> pretty ";",
                       pretty "let result_str = serde_json::to_string(&r).unwrap();",
                       pretty "witc_abi::instance::write(id, result_str.as_ptr() as usize, result_str.len());"
                     ]
            )
        )
    ]
  where
    getParameter :: (String, TypeVal) -> Doc a
    getParameter (x, ty) =
      hsep
        [ pretty "let",
          pretty x,
          pretty ":",
          genTypeRust ty,
          pretty "=",
          hcat
            [ pretty "serde_json::from_str(witc_abi::instance::read(id).to_string().as_str()).unwrap();"
            ]
        ]

-- runtime
toHostFunction :: String -> TypeSig -> Doc a
toHostFunction name (TyArrow param_list _result_ty) =
  pretty "#[wasmedge_sdk::host_function]"
    <+> line
    <+> hsep (map pretty ["fn", externalConvention name])
    <+> parens (pretty "caller: wasmedge_sdk::Caller, input: Vec<wasmedge_sdk::WasmValue>")
    <+> pretty "->"
    <+> pretty "Result<Vec<wasmedge_sdk::WasmValue>, wasmedge_sdk::error::HostFuncError>"
    <+> braces
      ( indent
          4
          ( hsep $
              [ pretty "let id = input[0].to_i32();"
              ]
                ++ map letParam param_list
                ++ [ pretty "let r ="
                       <+> pretty (normalizeIdentifier name)
                       <+> tupled (map (\(x, _) -> pretty x) param_list)
                       <+> pretty ";",
                     pretty "let result_str = serde_json::to_string(&r).unwrap();",
                     pretty "unsafe { witc_abi::runtime::STATE.put_buffer(id, result_str) }",
                     pretty "Ok(vec![])"
                   ]
          )
      )
  where
    letParam :: (String, TypeVal) -> Doc a
    letParam (x, ty) =
      hsep
        [ pretty "let",
          pretty x,
          pretty ":",
          genTypeRust ty,
          pretty "=",
          hcat
            [pretty "serde_json::from_str(unsafe { witc_abi::runtime::STATE.read_buffer(id).as_str() }).unwrap();"]
        ]

-- runtime wasm import object
witObject :: String -> [String] -> Doc a
witObject exportName defs =
  pretty "pub fn wit_import_object() -> wasmedge_sdk::WasmEdgeResult<wasmedge_sdk::ImportObject>"
    <+> braces
      ( pretty "Ok"
          <+> parens
            ( pretty "wasmedge_sdk::ImportObjectBuilder::new()"
                <+> vsep (map withFunc defs)
                <+> pretty
                  ( ".build(\""
                      ++ exportName
                      ++ "\")?"
                  )
            )
      )
  where
    withFunc :: String -> Doc a
    withFunc (pretty . externalConvention -> name) =
      -- i32: every convention function should just get the id of the queue
      -- (): returns nothing (real returns will be sent by queue)
      pretty ".with_func::<i32, ()>"
        <+> tupled [dquotes name, name]
        <+> pretty "?"
