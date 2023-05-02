module Wit.Gen.Export
  ( witObject,
    toHostFunction,
    toUnsafeExtern,
  )
where

import Prettyprinter
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

toUnsafeExtern :: Definition -> Doc a
toUnsafeExtern (SrcPos _ d) = toUnsafeExtern d
toUnsafeExtern (Func (Function name param_list _result_ty)) =
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
                map letParam param_list
                  ++ [ pretty "let r ="
                         <+> pretty (normalizeIdentifier name)
                         <+> tupled (map (\(x, _) -> pretty x) param_list)
                         <+> pretty ";",
                       pretty "let result_str = serde_json::to_string(&r).unwrap();",
                       pretty "write(id, result_str.as_ptr() as usize, result_str.len());"
                     ]
            )
        )
    ]
  where
    letParam :: (String, Type) -> Doc a
    letParam (x, ty) =
      hsep
        [ pretty "let",
          pretty x,
          pretty ":",
          prettyType ty,
          pretty "=",
          hcat
            [ pretty "serde_json::from_str(read(id).to_string().as_str()).unwrap();"
            ]
        ]
toUnsafeExtern d = error "should not get type definition here: " $ show d

toHostFunction :: Definition -> Doc a
toHostFunction (SrcPos _ d) = toHostFunction d
toHostFunction (Func (Function name param_list _result_ty)) =
  pretty "#[host_function]"
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
                     pretty "unsafe { STATE.put_buffer(id, result_str) }",
                     pretty "Ok(vec![])"
                   ]
          )
      )
  where
    letParam :: (String, Type) -> Doc a
    letParam (x, ty) =
      hsep
        [ pretty "let",
          pretty x,
          pretty ":",
          prettyType ty,
          pretty "=",
          hcat
            [pretty "serde_json::from_str(unsafe { STATE.read_buffer(id).as_str() }).unwrap();"]
        ]
toHostFunction d = error "should not get type definition here: " $ show d

witObject :: [Definition] -> Doc a
witObject defs =
  pretty "fn wit_import_object() -> wasmedge_sdk::WasmEdgeResult<wasmedge_sdk::ImportObject>"
    <+> braces
      ( pretty "Ok"
          <+> parens
            ( pretty "wasmedge_sdk::ImportObjectBuilder::new()"
                <+> vsep (map withFunc defs)
                <+> pretty ".build(\"wasmedge\")?"
            )
      )
  where
    withFunc :: Definition -> Doc a
    withFunc (SrcPos _ d) = withFunc d
    withFunc (Func (Function (pretty . externalConvention -> name) _ _)) =
      pretty ".with_func::"
        <+> angles
          ( -- every convention function should just get the id of the queue
            pretty "i32"
              <+> comma
              -- returns nothing (real returns will be sent by queue)
              <+> pretty "()"
          )
        <+> tupled [dquotes name, name]
        <+> pretty "?"
    withFunc d = error $ "bad definition" ++ show d
