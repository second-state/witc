module Wit.Gen.Import
  ( renderInstanceImport,
    renderRuntimeExport,
  )
where

import Data.List (partition)
import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

renderInstanceImport :: WitFile -> IO ()
renderInstanceImport f = putDoc $ prettyFile Config {language = Rust, direction = Import, side = Instance} f

renderRuntimeExport :: WitFile -> IO ()
renderRuntimeExport f = putDoc $ prettyFile Config {language = Rust, direction = Export, side = Runtime} f

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

prettyFile :: Config -> WitFile -> Doc a
prettyFile config WitFile {definition_list = def_list} =
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
        (_, _) -> error "unsupported side, direction combination"

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
