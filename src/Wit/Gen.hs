module Wit.Gen
  ( prettyFile,
  )
where

import Prettyprinter
import Wit.Check
import Wit.Config
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Plugin
import Wit.Gen.Type

prettyFile :: Config -> String -> CheckResult -> Doc a
prettyFile config inOutName CheckResult {tyEnv = tyEnv, context = context} =
  let prettyTyDefs = genTypeDefs tyEnv
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
                                (map prettyDefExtern context)
                            )
                          <+> line
                      )
                  ]
                    ++ map prettyDefWrap context
                )
          Instance Export ->
            prettyTyDefs
              <> line'
              <> vsep (map toUnsafeExtern context)
          Runtime Import ->
            prettyTyDefs
              <> line'
              <> vsep (map (toVmWrapper inOutName) context)
          Runtime Export ->
            prettyTyDefs
              <> line'
              <> vsep
                [ pretty $ "mod " ++ inOutName,
                  braces (vsep (witObject inOutName context : pretty "use wasmedge_sdk::Caller;" : pretty "use super::*;" : map toHostFunction context))
                ]
          Plugin pluginName ->
            vsep
              [ pretty "#[link(wasm_import_module ="
                  <+> dquotes (pretty pluginName)
                    <> pretty
                      ")]",
                pretty
                  "extern \"C\" {",
                indent 4 (vsep (map (convertFuncRust pluginName) context)),
                pretty "}"
              ]
      )
