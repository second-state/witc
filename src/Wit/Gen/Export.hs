module Wit.Gen.Export
  ( witObject,
  )
where

import Data.Maybe
import Prettyprinter
import Wit.Ast
import Wit.Check
import Wit.Gen.Normalization

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
    withFunc (Func (Function _attr name params result_ty)) =
      let nname = normalizeIdentifier name
       in pretty ".with_func::"
            <+> angles
              ( prettyEnc (sum $ map (i32Encoding Nothing . snd) params)
                  <+> comma
                  <+> prettyEnc (i32Encoding Nothing result_ty)
              )
            <+> tupled
              [ dquotes $ hcat [pretty "extern_", pretty nname],
                pretty nname
              ]
            <+> pretty "?"
    withFunc d = error $ "bad definition" ++ show d
