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
    versionOption = infoOption "0.2.1" (long "version" <> help "Show version")
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

check :: Maybe FilePath -> IO ()
check (Just file) = do
  dirExists <- doesDirectoryExist file
  if dirExists
    then checkDir file
    else do
      fileExists <- doesFileExist file
      if fileExists
        then checkFileWithDoneHint file
        else putStrLn "no file or directory"
check Nothing = do
  dir <- getCurrentDirectory
  checkDir dir

checkDir :: FilePath -> IO ()
checkDir dir = do
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  mapM_ (\f -> checkFileWithDoneHint (dir ++ "/" ++ f)) witFileList

checkFileWithDoneHint :: FilePath -> IO ()
checkFileWithDoneHint file = do
  checkFile file $> ()
  putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line

codegen :: Direction -> Side -> FilePath -> String -> IO ()
codegen d s file importName =
  parseFile file
    >>= eitherIO check0
    >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = d, side = s} importName)
