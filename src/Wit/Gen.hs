{-# LANGUAGE QuasiQuotes #-}

module Wit.Gen
  ( prettyFile,
    Config (..),
    SupportedLanguage (..),
    Direction (..),
    Side (..),
  )
where

import Data.List (partition)
import Prettyprinter
import QStr
import Wit.Ast
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Type

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

prettyFile :: Config -> String -> WitFile -> Doc a
prettyFile config importName WitFile {definition_list = def_list} =
  let (ty_defs, defs) = partition isTypeDef def_list
   in case (config.side, config.direction) of
        (Instance, Import) ->
          vsep $
            map prettyTypeDef ty_defs
              ++ [ pretty rustInstanceImportHelper,
                   pretty $ "#[link(wasm_import_module = " ++ "\"" ++ importName ++ "\")]",
                   pretty "extern \"wasm\"",
                   braces
                     ( line
                         <+> indent
                           4
                           ( vsep $
                               map
                                 pretty
                                 [ "fn allocate(size: usize) -> usize;",
                                   "fn write(addr: usize, byte: u8);",
                                   "fn read(addr: usize, offset: usize) -> u8;"
                                 ]
                                 ++ map prettyDefExtern defs
                           )
                         <+> line
                     )
                 ]
              ++ map prettyDefWrap defs
        (Instance, Export) ->
          vsep $
            map prettyTypeDef ty_defs
              ++ map toUnsafeExtern defs
        (Runtime, Import) ->
          vsep (map prettyTypeDef ty_defs ++ map (toVmWrapper importName) defs)
        (Runtime, Export) ->
          vsep (map prettyTypeDef ty_defs ++ map toHostFunction defs)
            <+> witObject defs

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True

rustInstanceImportHelper :: String
rustInstanceImportHelper =
  [str|
fn as_remote_string<A>(a: A) -> (usize, usize)
where A: Serialize,
{
  let s = serde_json::to_string(&a).unwrap();
  let remote_addr = unsafe { allocate(s.len() as usize) };
  unsafe {
    for c in s.bytes() {
      write(remote_addr, c);
    }
  }
  (remote_addr, s.len())
}

fn from_remote_string(pair: (usize, usize)) -> String {
  let (remote_addr, len) = pair;
  let mut s = String::with_capacity(len);
  unsafe {
    for i in 0..len {
      s.push(read(remote_addr, i) as char);
    }
  }
  s
}
|]
