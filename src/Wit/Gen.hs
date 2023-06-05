module Wit.Gen
  ( prettyFile,
  )
where

import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Config
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Plugin
import Wit.Gen.Type
import Wit.TypeValue

genContext :: M.Map String TypeSig -> (String -> TypeSig -> Doc a) -> Doc a
genContext m f =
  M.foldl (\acc x -> acc <> line <> x) mempty (M.mapWithKey f m)

prettyFile :: Config -> String -> CheckResult -> Doc a
prettyFile config inOutName CheckResult {tyEnv = ty_env, ctx = context} =
  let prettyTyDefs = genTypeDefs ty_env
   in ( case config.codegenMode of
          Instance Import ->
            prettyTyDefs
              <> line'
              <> ( ( pretty "#[link(wasm_import_module = "
                       <> dquotes (pretty inOutName)
                       <> pretty ")]"
                   )
                     <> line'
                     <> pretty "extern \"C\""
                     <+> braces
                       ( line
                           <> indent
                             4
                             (genContext context prettyDefExtern)
                           <> line
                       )
                       <> genContext context prettyDefWrap
                 )
          Instance Export ->
            prettyTyDefs
              <> line'
              <> genContext context toUnsafeExtern
          Runtime Import ->
            prettyTyDefs
              <> line'
              <> genContext context (toVmWrapper inOutName)
          Runtime Export ->
            prettyTyDefs
              <> line'
              <> vsep
                [ pretty $ "mod " ++ inOutName,
                  braces
                    ( witObject inOutName (M.keys context)
                        <> line'
                        <> pretty "use wasmedge_sdk::Caller;"
                        <> line'
                        <> pretty "use super::*;"
                        <> line'
                        <> genContext context toHostFunction
                    )
                ]
          Plugin pluginName ->
            vsep
              [ pretty "#[link(wasm_import_module ="
                  <+> dquotes (pretty pluginName)
                    <> pretty
                      ")]",
                pretty
                  "extern \"C\"",
                braces $ indent 4 (genContext context (convertFuncRust pluginName))
              ]
      )
