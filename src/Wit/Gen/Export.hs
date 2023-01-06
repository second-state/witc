module Wit.Gen.Export
  ( witObject,
    implRuntime,
    toHostFunction,
  )
where

import Data.Maybe
import Prettyprinter
import Wit.Ast
import Wit.Check
import Wit.Gen.Normalization
import Wit.Gen.Type

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
          ( vsep (map letParam param_list)
              <+> line
              <+> pretty "let r ="
              <+> pretty (normalizeIdentifier name)
              <+> parens (hsep (map (pretty . fst) param_list))
              <+> pretty ";"
              <+> line
              <+> pretty "Ok(vec![WasmValue::from_i32(r as i32)])"
          )
      )
  where
    letParam :: (String, Type) -> Doc a
    letParam (x, ty) =
      hsep
        [ pretty "let",
          tupled [pretty x, pretty "input"],
          pretty "=",
          hcat
            [prettyType ty, pretty "::", pretty "new_by_runtime(&caller, input);"]
        ]
toHostFunction d = error "should not get type definition here: " $ show d

implRuntime :: Definition -> Doc a
implRuntime (SrcPos _ d) = implRuntime d
implRuntime (Record name fields) =
  hsep (map pretty ["impl", "Runtime", "for", name])
    <+> braces
      ( line
          <+> indent
            4
            ( vsep
                [ hsep (map pretty ["fn", "size()", "->", "usize"])
                    <+> encloseSep
                      lbrace
                      rbrace
                      (pretty "+")
                      (map (fieldTypeSize . snd) fields),
                  hsep
                    ( map
                        pretty
                        [ "fn",
                          "new_by_runtime",
                          "(",
                          "caller: &wasmedge_sdk::Caller, input: Vec<wasmedge_sdk::WasmValue>",
                          ")",
                          "->",
                          "(Self, Vec<wasmedge_sdk::WasmValue>)"
                        ]
                    )
                    <+> braces
                      ( line
                          <+> indent
                            4
                            ( vsep (map letField fields)
                                <+> tupled [recordCtor, pretty "input"]
                            )
                      )
                ]
            )
      )
  where
    fieldTypeSize ty =
      case ty of
        SrcPosType _ t -> fieldTypeSize t
        PrimI8 -> pretty "4"
        PrimI16 -> pretty "4"
        PrimI32 -> pretty "4"
        PrimU8 -> pretty "4"
        PrimU16 -> pretty "4"
        PrimU32 -> pretty "4"
        _ -> hcat [prettyABIType ty, pretty "::", pretty "size()"]

    recordCtor = pretty name <+> encloseSep lbrace rbrace comma (map (fieldInto . fst) fields)
    fieldInto x = pretty x <+> pretty ":" <+> hcat [pretty x, pretty ".into()"]

    letField :: (String, Type) -> Doc a
    letField (x, ty) =
      hsep
        [ pretty "let",
          tupled [pretty x, pretty "input"],
          pretty "=",
          newByRuntime ty
        ]
    newByRuntime :: Type -> Doc a
    newByRuntime ty = case ty of
      SrcPosType _ t -> newByRuntime t
      PrimI8 -> pretty "(input[0].to_i32() as i8, input[1..].into());"
      PrimI16 -> pretty "(input[0].to_i32() as i16, input[1..].into());"
      PrimI32 -> pretty "(input[0].to_i32() as i32, input[1..].into());"
      PrimU8 -> pretty "(input[0].to_i32() as u8, input[1..].into());"
      PrimU16 -> pretty "(input[0].to_i32() as u16, input[1..].into());"
      PrimU32 -> pretty "(input[0].to_i32() as u32, input[1..].into());"
      _ -> hcat [prettyABIType ty, pretty "::", pretty "new_by_runtime(&caller, input);"]
implRuntime (Variant _ _) = emptyDoc
implRuntime (Enum name cases) =
  hsep (map pretty ["impl", "Runtime", "for", name])
    <+> braces
      ( line
          <+> indent
            4
            ( hsep (map pretty ["fn", "size()", "->", "usize"])
                <+> braces (pretty "4")
                <+> line
                <+> hsep
                  ( map
                      pretty
                      [ "fn",
                        "new_by_runtime",
                        "(",
                        "caller: &wasmedge_sdk::Caller, input: Vec<wasmedge_sdk::WasmValue>",
                        ")",
                        "->",
                        "(Self, Vec<wasmedge_sdk::WasmValue>)"
                      ]
                  )
                <+> braces
                  ( pretty "let r = match input[0].to_i32()"
                      <+> encloseSep lbrace rbrace comma (c 0 cases)
                      <+> pretty ";"
                      <+> line
                      <+> pretty "(r, input[1..].into())"
                  )
            )
          <+> line
      )
  where
    c :: Int -> [String] -> [Doc a]
    c n (c' : cs) = hsep [pretty n, pretty "=>", toRustName c'] : c (n + 1) cs
    c _ [] = [pretty "_ => unreachable!()"]
    toRustName :: String -> Doc a
    toRustName tag_name = hcat $ map pretty [name, "::", tag_name]
implRuntime _ = emptyDoc

witObject :: Env -> [Definition] -> Doc a
witObject env defs =
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
    i32Encoding :: Maybe String -> Type -> Int
    i32Encoding n (SrcPosType _ ty) = i32Encoding n ty
    i32Encoding _n PrimString = 3
    i32Encoding _n PrimU8 = 1
    i32Encoding _n PrimU16 = 1
    i32Encoding _n PrimU32 = 1
    i32Encoding _n PrimU64 = 1
    i32Encoding _n PrimI8 = 1
    i32Encoding _n PrimI16 = 1
    i32Encoding _n PrimI32 = 1
    i32Encoding _n PrimI64 = 1
    i32Encoding _n PrimChar = 1
    i32Encoding _n PrimF32 = 1
    i32Encoding _n PrimF64 = 1
    i32Encoding n (Optional ty) = 1 + i32Encoding n ty
    i32Encoding _n (ListTy _ty) = 3
    i32Encoding n (ExpectedTy a b) = 1 + (i32Encoding n a `max` i32Encoding n b)
    i32Encoding n (TupleTy ty_list) = sum $ map (i32Encoding n) ty_list
    i32Encoding Nothing (User name) = i32Encoding Nothing $ fromJust $ lookupEnv name env
    i32Encoding (Just n) (User name) =
      if n == name
        then 1
        else i32Encoding (Just n) $ fromJust $ lookupEnv name env
    -- execution
    i32Encoding _ (VSum name ty_list) = foldl max 0 (map (i32Encoding $ Just name) ty_list) + 1

    prettyEnc :: Int -> Doc a
    prettyEnc 0 = pretty "()"
    prettyEnc 1 = pretty "i32"
    prettyEnc n = tupled $ replicate n (pretty "i32")

    withFunc :: Definition -> Doc a
    withFunc (SrcPos _ d) = withFunc d
    withFunc (Func (Function _attr (pretty . externalConvention -> name) params result_ty)) =
      pretty ".with_func::"
        <+> angles
          ( prettyEnc (sum $ map (i32Encoding Nothing . snd) params)
              <+> comma
              <+> prettyEnc (i32Encoding Nothing result_ty)
          )
        <+> tupled [dquotes name, name]
        <+> pretty "?"
    withFunc d = error $ "bad definition" ++ show d
