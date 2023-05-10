{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
    witc check xxx.wit
    witc check -- check all wit files in current directory
-}
module Main (main) where

import Control.Monad
import Control.Monad.Except
import Control.Monad.State
import Data.List (isSuffixOf)
import Data.Map.Lazy qualified as Map
import Options.Applicative
import Prettyprinter
import Prettyprinter.Render.Terminal
import System.Directory
import System.Exit (exitSuccess)
import Wit

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
    versionOption = infoOption "0.2.1" (long "version" <> help "Show version")
    programOptions :: Parser (IO ())
    programOptions =
      subparser
        ( command
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
                              ( codegen Import Instance
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> strArgument (value "wasmedge" <> help "Name of import")
                              )
                              (progDesc "Generate import code for instance (wasm)")
                          )
                          <> command
                            "export"
                            ( info
                                ( codegen Export Instance
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
                              ( codegen Import Runtime
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> strArgument (value "wasmedge" <> help "Name of import")
                              )
                              (progDesc "Generate import code for runtime (WasmEdge)")
                          )
                          <> command
                            "export"
                            ( info
                                ( codegen Export Runtime
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
        then checkFileWithDoneHint file
        else putStrLn "no file or directory"
checkCmd Nothing = do
  dir <- getCurrentDirectory
  checkDir dir

checkDir :: FilePath -> IO ()
checkDir dir = do
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  mapM_ (\f -> checkFileWithDoneHint (dir ++ "/" ++ f)) witFileList

checkFileWithDoneHint :: FilePath -> IO ()
checkFileWithDoneHint file = do
  runWithErrorHandler
    (checkPath file)
    printCheckError
    (\_ -> putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line)

printCheckError :: CheckError -> IO ()
printCheckError e = do
  putDoc $ annotate (color Red) $ pretty e
  return ()

codegen :: Direction -> Side -> FilePath -> String -> IO ()
codegen d s file importName = do
  wit <- runExit $ checkPath file
  (putDoc . prettyFile Config {language = Rust, direction = d, side = s} importName) wit

runExit :: ExceptT CheckError IO a -> IO a
runExit act = runWithErrorHandler act (\e -> putDoc (annotate (color Red) $ pretty e) *> exitSuccess) pure

runWithErrorHandler :: ExceptT CheckError IO a -> (CheckError -> IO b) -> (a -> IO b) -> IO b
runWithErrorHandler act onErr onSuccess = do
  result <- runExceptT act
  case result of
    Left e -> onErr e
    Right a -> onSuccess a

checkPath :: FilePath -> ExceptT CheckError IO WitFile
checkPath path = do
  ast <- parseFile' path
  evalStateT (check' ast) []

check' :: WitFile -> StateT [CheckError] (ExceptT CheckError IO) WitFile
check' = check Map.empty

parseFile' :: FilePath -> ExceptT CheckError IO WitFile
parseFile' = parseFile
