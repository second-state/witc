module Wit.Gen
  ( prettyFile,
  )
where

import Data.List (partition)
import Prettyprinter
import Wit.Ast
import Wit.Config
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Plugin
import Wit.Gen.Type
import Wit.Transform

prettyFile :: Config -> String -> WitFile -> Doc a
prettyFile config inOutName WitFile {definition_list = (transformDefinitions -> def_list)} =
  let (ty_defs, defs) = partition isTypeDef def_list
   in let prettyTyDefs = vsep (map prettyTypeDef ty_defs)
       in ( case config.codegenMode of
              Instance Import ->
                prettyTyDefs
                  <> line'
                  <> vsep
                    ( [ pretty $ "#[link(wasm_import_module = " ++ "\"" ++ inOutName ++ "\")]",
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
                    )
              Instance Export ->
                prettyTyDefs
                  <> line'
                  <> vsep (map toUnsafeExtern defs)
              Runtime Import ->
                prettyTyDefs
                  <> line'
                  <> vsep (map (toVmWrapper inOutName) defs)
              Runtime Export ->
                prettyTyDefs
                  <> line'
                  <> vsep
                    [ pretty $ "mod " ++ inOutName,
                      braces (vsep (witObject inOutName defs : pretty "use wasmedge_sdk::Caller;" : pretty "use super::*;" : map toHostFunction defs))
                    ]
              Plugin pluginName ->
                vsep
                  [ pretty "#[link(wasm_import_module ="
                      <+> dquotes (pretty pluginName)
                        <> pretty
                          ")]",
                    pretty
                      "extern \"C\" {",
                    indent 4 (vsep (map (convertFuncRust pluginName) defs)),
                    pretty "}"
                  ]
          )

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
