{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
    witc check xxx.wit
    witc check -- check all wit files in current directory
-}
module Main (main) where

import Data.Map.Lazy qualified as M
import Control.Monad
import Control.Monad.Except
import Control.Monad.Reader
import Control.Monad.State
import Data.List (isSuffixOf)
import Options.Applicative
import Prettyprinter
import Prettyprinter.Render.Terminal
import System.Directory
import System.Exit
import System.FilePath
import Wit.Check
import Wit.Config
import Wit.Gen

main :: IO ()
main = do
  join $
    execParser
      ( info
          (helper <*> versionOption <*> programOptions)
          ( fullDesc
              <> progDesc "compiler for wit"
              <> header
                "witc - compiler for wit, a language for describing wasm interface types"
          )
      )
  where
    versionOption :: Parser (a -> a)
    versionOption = infoOption "0.3.1" (long "version" <> help "Show version")
    programOptions :: Parser (IO ())
    programOptions =
      subparser
        ( command
            "plugin"
            ( info
                (codegenPluginCmd <$> strArgument (metavar "FILE" <> help "Wit file"))
                (progDesc "Generate plugin import code for wasm module")
            )
            <> command
              "check"
              ( info
                  (checkCmd <$> optional (strArgument (metavar "FILE" <> help "Name of the thing to create")))
                  (progDesc "Validate wit file")
              )
            <> command
              "instance"
              ( info
                  ( subparser
                      ( command
                          "import"
                          ( info
                              ( codegenCmd (Instance Import)
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> strArgument (value "wasmedge" <> help "Name of import")
                              )
                              (progDesc "Generate import code for instance (wasm)")
                          )
                          <> command
                            "export"
                            ( info
                                ( codegenCmd (Instance Export)
                                    <$> strArgument (metavar "FILE" <> help "Wit file")
                                    <*> strArgument (value "wasmedge" <> help "Name of export")
                                )
                                (progDesc "Generate export code for instance (wasm)")
                            )
                      )
                  )
                  (progDesc "Generate code for instance (wasm)")
              )
            <> command
              "runtime"
              ( info
                  ( subparser
                      ( command
                          "import"
                          ( info
                              ( codegenCmd (Runtime Import)
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> strArgument (value "wasmedge" <> help "Name of import")
                              )
                              (progDesc "Generate import code for runtime (WasmEdge)")
                          )
                          <> command
                            "export"
                            ( info
                                ( codegenCmd (Runtime Export)
                                    <$> strArgument (metavar "FILE" <> help "Wit file")
                                    <*> strArgument (value "wasmedge" <> help "Name of export")
                                )
                                (progDesc "Generate export code for runtime (WasmEdge)")
                            )
                      )
                  )
                  (progDesc "Generate code for runtime (WasmEdge)")
              )
        )

checkCmd :: Maybe FilePath -> IO ()
checkCmd (Just file) = do
  dirExists <- doesDirectoryExist file
  if dirExists
    then checkDir file
    else do
      fileExists <- doesFileExist file
      if fileExists
        then checkFileWithDoneHint (takeDirectory file) (takeFileName file)
        else putStrLn "no file or directory"
checkCmd Nothing = do
  dir <- getCurrentDirectory
  checkDir dir

checkDir :: FilePath -> IO ()
checkDir dir = do
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  forM_ witFileList $
    \f -> checkFileWithDoneHint dir f

checkFileWithDoneHint :: FilePath -> FilePath -> IO ()
checkFileWithDoneHint dir file = do
  runWithErrorHandler
    (checkFile dir file)
    printCheckError
    (\_ -> putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line)

printCheckError :: CheckError -> IO ()
printCheckError e = do
  putDoc $ annotate (color Red) $ pretty e
  return ()

codegenPluginCmd :: FilePath -> IO ()
codegenPluginCmd file = do
  let pluginName = takeBaseName file
  codegenCmd (Plugin pluginName) file pluginName

codegenCmd :: Mode -> FilePath -> String -> IO ()
codegenCmd mode file importName = do
  checkResult <- runExit $ checkFile (takeDirectory file) (takeFileName file)
  (putDoc . prettyFile Config {language = Rust, codegenMode = mode} importName) checkResult

runExit :: ExceptT CheckError IO a -> IO a
runExit act = runWithErrorHandler act (\e -> putDoc (annotate (color Red) $ pretty e) *> exitFailure) pure

runWithErrorHandler :: ExceptT CheckError IO a -> (CheckError -> IO b) -> (a -> IO b) -> IO b
runWithErrorHandler act onErr onSuccess = do
  result <- runExceptT act
  case result of
    Left e -> onErr e
    Right a -> onSuccess a

checkFile :: FilePath -> FilePath -> ExceptT CheckError IO CheckResult
checkFile dirpath filepath = do
  (todoList, parsed) <- runReaderT (trackFile filepath) dirpath
  forM todoList $ \file -> do
    case M.lookup file parsed of
      Nothing -> error "impossible"
      Just ast -> runReaderT (evalStateT (check ast) emptyCheckState) dirpath
  return CheckResult {tyEnv = M.empty, ctx = M.empty}
