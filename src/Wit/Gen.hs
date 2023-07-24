module Wit.Gen
  ( prettyFile,
  )
where

import Control.Monad.Reader
import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Config
import Wit.Gen.Export
import Wit.Gen.Import
import Wit.Gen.Plugin
import Wit.Gen.Type

genContext ::
  MonadReader (M.Map FilePath CheckResult) m =>
  M.Map String t ->
  (String -> t -> m (Doc a)) ->
  m (Doc a)
genContext m f = do
  let m' = M.toList m
  t <- forM m' (uncurry f)
  return $ foldl (\acc x -> acc <> line <> x) mempty t

prettyFile :: MonadReader (M.Map FilePath CheckResult) m => Config -> String -> FilePath -> m (Doc a)
prettyFile config inOutName targetMod = do
  checked <- ask
  let CheckResult {tyEnv = ty_env, ctx = context} = checked M.! targetMod
  prettyTyDefs <- genContext ty_env genTypeDefRust
  case config.codegenMode of
    Instance Import -> do
      r <- genContext context prettyDefExtern
      r2 <- genContext context prettyDefWrap
      return $
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
                       <> indent 4 r
                       <> line
                   )
                   <> r2
             )
    Instance Export -> do
      r <- genContext context toUnsafeExtern
      return $
        prettyTyDefs
          <> line'
          <> r
    Runtime Import -> do
      r <- genContext context (toVmWrapper inOutName)
      return $
        prettyTyDefs
          <> line'
          <> r
    Runtime Export -> do
      r <- genContext context toHostFunction
      return $
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
                    <> r
                )
            ]
    Plugin pluginName -> do
      r <- genContext context (convertFuncRust pluginName)
      return $
        vsep
          [ prettyTyDefs,
            pretty "#[link(wasm_import_module ="
              <+> dquotes (pretty pluginName)
                <> pretty
                  ")]",
            pretty
              "extern \"C\""
              <+> braces (indent 4 r)
          ]
