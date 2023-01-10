module Wit.Gen
  ( renderInstanceImport,
    renderRuntimeExport,
  )
where

import Data.List (partition)
import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Check
import Wit.Gen.Export
import Wit.Gen.Import
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
            <+> line
            <+> vsep (map toHostFunction defs)
            <+> witObject defs
        (_, _) -> error "unsupported side, direction combination"
