module Wit.Gen.Import
  ( renderInstanceImport,
    renderRuntimeExport,
  )
where

import Data.List (partition)
import Data.Maybe
import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Check
import Wit.Gen.Normalization
import Wit.Gen.Type

renderInstanceImport :: (WitFile, Env) -> IO ()
renderInstanceImport (f, env) = putDoc $ prettyFile Config {language = Rust, direction = Import, side = Instance} f env

renderRuntimeExport :: (WitFile, Env) -> IO ()
renderRuntimeExport (f, env) = putDoc $ prettyFile Config {language = Rust, direction = Export, side = Runtime} f env

data SupportedLanguage
  = Rust

data Direction
  = Import
  | Export

data Side
  = Instance
  | Runtime

data Config = Config
  { language :: SupportedLanguage,
    direction :: Direction,
    side :: Side
  }

prettyFile :: Config -> WitFile -> Env -> Doc a
prettyFile config WitFile {definition_list = def_list} env =
  let (ty_defs, defs) = partition isTypeDef def_list
   in case (config.side, config.direction) of
        (Instance, Import) ->
          vsep (map prettyTypeDef ty_defs)
            <+> line
            <+> pretty "#[link(wasm_import_module = \"wasmedge\")]"
            <+> line
            <+> pretty "extern \"wasm\""
            <+> braces (line <+> indent 4 (vsep (map prettyDefExtern defs)) <+> line)
            <+> line
            <+> vsep (map prettyDefWrap defs)
        (Runtime, Export) ->
          vsep (map prettyTypeDef ty_defs)
            <+> witObject env defs
        (_, _) -> error "unsupported side, direction combination"

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

    g :: [Type] -> Type -> (Int, Int)
    g param_types r_ty = (sum $ map (i32Encoding Nothing) param_types, i32Encoding Nothing r_ty)

    prettyEnc :: Int -> Doc a
    prettyEnc 0 = pretty "()"
    prettyEnc 1 = pretty "i32"
    prettyEnc n = tupled $ replicate n (pretty "i32")

    withFunc :: Definition -> Doc a
    withFunc (SrcPos _ d) = withFunc d
    withFunc (Func (Function _attr name params result_ty)) =
      let nname = normalizeIdentifier name
       in let (n, m) = g (map snd params) result_ty
           in pretty ".with_func::"
                <+> angles (prettyEnc n <+> comma <+> prettyEnc m)
                <+> tupled
                  [ dquotes $ hcat [pretty "extern_", pretty nname],
                    pretty nname
                  ]
                <+> pretty "?"
    withFunc d = error $ "bad definition" ++ show d

prettyDefWrap :: Definition -> Doc a
prettyDefWrap (SrcPos _ d) = prettyDefWrap d
prettyDefWrap (Resource _ _) = undefined
prettyDefWrap (Func (Function _attr name param_list result_ty)) =
  hsep (map pretty ["fn", normalizeIdentifier name])
    <+> parens (hsep $ punctuate comma (map prettyBinder param_list))
    <+> hsep [pretty "->", prettyType result_ty]
    <+> braces
      ( -- unsafe call extern function
        hsep
          [ pretty $ "unsafe { extern_" ++ normalizeIdentifier name,
            pretty "(",
            hsep $ punctuate comma (map (paramInto . fst) param_list),
            pretty ") }.into()"
          ]
      )
  where
    paramInto :: String -> Doc a
    paramInto s = pretty $ s ++ ".into()"
prettyDefWrap d = error "should not get type definition here: " $ show d

prettyDefExtern :: Definition -> Doc a
prettyDefExtern (SrcPos _ d) = prettyDefExtern d
prettyDefExtern (Resource _name _) = undefined
prettyDefExtern (Func (Function _attr name param_list result_ty)) =
  hsep (map pretty ["fn", "extern_" ++ normalizeIdentifier name])
    <+> parens (hsep $ punctuate comma (map prettyABIBinder param_list))
    <+> pretty "->"
    <+> prettyABIType result_ty
    <+> pretty ";"
prettyDefExtern d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
