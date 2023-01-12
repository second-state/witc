module Wit.Gen
  ( renderInstanceImport,
    renderRuntimeExport,
  )
where

import Data.List (partition)
import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Gen.Export
import Wit.Gen.Import
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
            <+> pretty "fn as_remote_string<A>(a: A) -> (usize, usize) where A: Serialize, { let s = serde_json::to_string(&a).unwrap(); let remote_addr = unsafe { allocate(s.len() as usize) }; unsafe { for (i, c) in s.bytes().enumerate() { write(remote_addr, i, c); } } (remote_addr, s.len()) } fn from_remote_string(pair: (usize, usize)) -> String { let (remote_addr, len) = pair; let mut s = String::with_capacity(len); unsafe { for i in 0..len { s.push(read(remote_addr, i) as char); } } s }"
            <+> line
            <+> pretty "#[link(wasm_import_module = \"wasmedge\")]"
            <+> line
            <+> pretty "extern \"wasm\""
            <+> braces
              ( line
                  <+> indent
                    4
                    ( vsep $
                        map
                          pretty
                          [ "fn allocate(size: usize) -> usize;",
                            "fn write(addr: usize, offset: usize, byte: u8);",
                            "fn read(addr: usize, offset: usize) -> u8;"
                          ]
                          ++ map prettyDefExtern defs
                    )
                  <+> line
              )
            <+> line
            <+> vsep (map prettyDefWrap defs)
        (Runtime, Export) ->
          vsep (map prettyTypeDef ty_defs)
            <+> line
            <+> vsep (map toHostFunction defs)
            <+> witObject defs
        (_, _) -> error "unsupported side, direction combination"

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
