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
import Wit.Ast
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Type
import Wit.Transform

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
prettyFile config inOutName WitFile {definition_list = (transformDefinitions -> def_list)} =
  let (ty_defs, defs) = partition isTypeDef def_list
   in vsep
        ( map prettyTypeDef ty_defs
            ++ ( case (config.side, config.direction) of
                   (Instance, Import) ->
                     [ pretty $ "#[link(wasm_import_module = " ++ "\"" ++ inOutName ++ "\")]",
                       pretty "extern \"C\"",
                       braces
                         ( line
                             <+> indent
                               4
                               ( vsep
                                   (map prettyDefExtern defs)
                               )
                             <+> line
                         )
                     ]
                       ++ map prettyDefWrap defs
                   (Instance, Export) -> map toUnsafeExtern defs
                   (Runtime, Import) -> map (toVmWrapper inOutName) defs
                   (Runtime, Export) -> [pretty $ "mod " ++ inOutName, braces (vsep (witObject inOutName defs : pretty "use wasmedge_sdk::Caller;" : pretty "use super::*;" : map toHostFunction defs))]
               )
        )

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
