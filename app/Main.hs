{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
    witc check xxx.wit
    witc check -- check all wit files in current directory
-}
module Main (main) where

import Control.Monad
import Data.Functor
import Data.List (isSuffixOf)
import Options.Applicative
import Prettyprinter
import Prettyprinter.Render.Terminal
import System.Directory
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
    versionOption = infoOption "0.2" (long "version" <> help "Show version")
    programOptions :: Parser (IO ())
    programOptions =
      subparser
        ( command
            "check"
            ( info
                (check <$> optional (strArgument (metavar "FILE" <> help "Name of the thing to create")))
                (progDesc "Validate wit file")
            )
            <> command
              "instance"
              ( info
                  ( subparser
                      ( command
                          "import"
                          ( info
                              ( instanceImport
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> optional (strArgument (metavar "NAME" <> help "Name of import"))
                              )
                              (progDesc "test")
                          )
                          <> command
                            "export"
                            ( info
                                (instanceExport <$> strArgument (metavar "FILE" <> help "Wit file"))
                                (progDesc "test")
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
                              ( runtimeImport
                                  <$> strArgument (metavar "FILE" <> help "Wit file")
                                  <*> optional (strArgument (metavar "NAME" <> help "Name of import"))
                              )
                              (progDesc "test")
                          )
                          <> command
                            "export"
                            ( info
                                (runtimeExport <$> strArgument (metavar "FILE" <> help "Wit file"))
                                (progDesc "test")
                            )
                      )
                  )
                  (progDesc "Generate code for runtime (WasmEdge)")
              )
        )

check :: Maybe FilePath -> IO ()
check (Just file) = checkFileWithDoneHint file
check Nothing = do
  dir <- getCurrentDirectory
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  mapM_ checkFileWithDoneHint witFileList

checkFileWithDoneHint :: FilePath -> IO ()
checkFileWithDoneHint file = do
  checkFile file $> ()
  putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line

instanceImport :: FilePath -> Maybe String -> IO ()
instanceImport file (Just importName) = codegen file Import Instance importName
instanceImport file Nothing = codegen file Import Instance "wasmedge"

instanceExport :: FilePath -> IO ()
instanceExport file = codegen file Export Instance "wasmedge"

runtimeImport :: FilePath -> Maybe String -> IO ()
runtimeImport file (Just importName) = codegen file Import Runtime importName
runtimeImport file Nothing = codegen file Import Runtime "wasmedge"

runtimeExport :: FilePath -> IO ()
runtimeExport file = codegen file Export Runtime "wasmedge"

codegen :: FilePath -> Direction -> Side -> String -> IO ()
codegen file d s importName =
  parseFile file
    >>= eitherIO check0
    >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = d, side = s} importName)
