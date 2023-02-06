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
toUnsafeExtern (Resource _ _) = undefined
toUnsafeExtern (Func (Function _attr name param_list _result_ty)) =
  vsep
    [ pretty "#[no_mangle]",
      pretty "pub unsafe extern \"wasm\"",
      hsep
        [ pretty "fn",
          pretty $ externalConvention name,
          parens $ hsep $ punctuate comma (map prettyBinder param_list),
          pretty "-> (usize, usize)"
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
                       pretty "let len = result_str.len();",
                       pretty "BUCKET[0] = result_str;",
                       pretty "(0, len)"
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
            [ pretty "serde_json::from_str(&BUCKET[",
              pretty x,
              pretty ".0]).unwrap();"
            ]
        ]

    prettyBinder :: (String, Type) -> Doc a
    prettyBinder (normalizeIdentifier -> n, _) = hsep [pretty n, pretty ": (usize, usize)"]
toUnsafeExtern d = error "should not get type definition here: " $ show d

toHostFunction :: Definition -> Doc a
toHostFunction (SrcPos _ d) = toHostFunction d
toHostFunction (Resource _ _) = undefined
toHostFunction (Func (Function _attr name param_list _result_ty)) =
  pretty "#[host_function]"
    <+> line
    <+> hsep (map pretty ["fn", externalConvention name])
    <+> parens (pretty "caller: wasmedge_sdk::Caller, input: Vec<wasmedge_sdk::WasmValue>")
    <+> pretty "->"
    <+> pretty "Result<Vec<wasmedge_sdk::WasmValue>, wasmedge_sdk::error::HostFuncError>"
    <+> braces
      ( indent
          4
          ( vsep $
              map letParam param_list
                ++ [ pretty "let r ="
                       <+> pretty (normalizeIdentifier name)
                       <+> tupled (map (\(x, _) -> pretty x) param_list)
                       <+> pretty ";",
                     pretty "let mut result_str = serde_json::to_string(&r).unwrap();",
                     pretty "let len = result_str.len() as i32;",
                     pretty "unsafe { COUNT = 0; BUCKET[COUNT] = result_str; }",
                     pretty "Ok(vec![wasmedge_sdk::WasmValue::from_i32(0), wasmedge_sdk::WasmValue::from_i32(len)])"
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
            [pretty "serde_json::from_str(unsafe { BUCKET[input[0].to_i32() as usize].as_str() }).unwrap();"]
        ]
        <+> pretty "let input: Vec<wasmedge_sdk::WasmValue> = input[2..].into();"
toHostFunction d = error "should not get type definition here: " $ show d

witObject :: [Definition] -> Doc a
witObject defs =
  pretty "fn wit_import_object() -> wasmedge_sdk::WasmEdgeResult<wasmedge_sdk::ImportObject>"
    <+> braces
      ( pretty "Ok"
          <+> parens
            ( pretty "wasmedge_sdk::ImportObjectBuilder::new()"
                <+> pretty ".with_func::<i32, i32>(\"allocate\", allocate)?"
                <+> pretty ".with_func::<(i32, i32), ()>(\"write\", write)?"
                <+> pretty ".with_func::<(i32, i32), i32>(\"read\", read)?"
                <+> vsep (map withFunc defs)
                <+> pretty ".build(\"wasmedge\")?"
            )
      )
  where
    prettyEnc :: Int -> Doc a
    prettyEnc 0 = pretty "()"
    prettyEnc 1 = pretty "i32"
    prettyEnc n = tupled $ replicate n (pretty "i32")

    withFunc :: Definition -> Doc a
    withFunc (SrcPos _ d) = withFunc d
    withFunc (Func (Function _attr (pretty . externalConvention -> name) params _)) =
      pretty ".with_func::"
        <+> angles
          ( -- get a list of string, each is a (addr, size) pair
            prettyEnc (2 * length params)
              <+> comma
              -- returns a allocated string anyway
              <+> prettyEnc 2
          )
        <+> tupled [dquotes name, name]
        <+> pretty "?"
    withFunc d = error $ "bad definition" ++ show d
