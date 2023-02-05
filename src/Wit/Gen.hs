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
            pretty rustInstanceExportHelper
              : map prettyTypeDef ty_defs
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
			// TODO: group every 8 char to one u64, in big endian
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
			// TODO: read out should be u64, not u8
      s.push(read(remote_addr, i) as char);
    }
  }
  s
}
|]

rustInstanceExportHelper :: String
rustInstanceExportHelper =
  [str|
const EMPTY_STRING: String = String::new();
pub static mut BUCKET: [String; 100] = [EMPTY_STRING; 100];
pub static mut COUNT: usize = 0;

#[no_mangle]
pub unsafe extern "wasm" fn allocate(size: usize) -> usize {
    let s = String::with_capacity(size);
    BUCKET[COUNT] = s;
    let count = COUNT;
    COUNT += 1;
    count
}
#[no_mangle]
pub unsafe extern "wasm" fn write(count: usize, byte: u8) {
		// TODO: expected u64
    let s = &mut BUCKET[count];
    s.push(byte as char);
}
#[no_mangle]
pub unsafe extern "wasm" fn read(count: usize, offset: usize) -> u8 {
		// TODO: return u64
    let s = &BUCKET[count];
    s.as_bytes()[offset]
}
|]
