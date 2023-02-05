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
                                   "fn write(addr: usize, data: u32, data2: u32);",
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
  let mut s = serde_json::to_string(&a).unwrap();
  let remote_addr = unsafe { allocate(s.len() as usize) };
  unsafe {
    let cc = s.as_bytes().chunks_exact(8);
    let rest = cc.remainder();
    for c in cc {
      let data = u32::from_be_bytes([c[0], c[1], c[2], c[3]]);
      let data2 = u32::from_be_bytes([c[4], c[5], c[6], c[7]]);
      write(remote_addr, data, data2);
    }
    match rest.len() {
      1 => {
        let data = u32::from_be_bytes([rest[0], 0, 0, 0]);
        write(remote_addr, data, 0);
      }
      2 => {
        let data = u32::from_be_bytes([rest[0], rest[1], 0, 0]);
        write(remote_addr, data, 0);
      }
      3 => {
        let data = u32::from_be_bytes([rest[0], rest[1], rest[2], 0]);
        write(remote_addr, data, 0);
      }
      4 => {
        let data = u32::from_be_bytes([rest[0], rest[1], rest[2], rest[3]]);
        write(remote_addr, data, 0);
      }
      5 => {
        let data = u32::from_be_bytes([rest[0], rest[1], rest[2], rest[3]]);
        let data2 = u32::from_be_bytes([rest[4], 0, 0, 0]);
        write(remote_addr, data, data2);
      }
      6 => {
        let data = u32::from_be_bytes([rest[0], rest[1], rest[2], rest[3]]);
        let data2 = u32::from_be_bytes([rest[4], rest[5], 0, 0]);
        write(remote_addr, data, data2);
      }
      7 => {
        let data = u32::from_be_bytes([rest[0], rest[1], rest[2], rest[3]]);
        let data2 = u32::from_be_bytes([rest[4], rest[5], rest[6], 0]);
        write(remote_addr, data, data2);
      }
      _ => unreachable!()
    }
  }
  (remote_addr, s.len())
}

fn from_remote_string(pair: (usize, usize)) -> String {
  let (remote_addr, len) = pair;
  let mut s = String::with_capacity(len);
  unsafe {
    for i in 0..len {
			// TODO: read out should be u64, not u8
      s.push(read(remote_addr, i) as char);
    }
  }
  s
}
|]
