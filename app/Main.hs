{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
    witc check xxx.wit
    witc check -- check all wit files in current directory
-}
module Main (main) where

import Data.Functor
import Data.List (isSuffixOf)
import Prettyprinter
import Prettyprinter.Render.Terminal
import System.Directory
import System.Environment
import Wit

handle :: [String] -> IO ()
handle ["version"] = putStrLn "0.1.0"
handle ["check", file] = checkFileWithDoneHint file
handle ["check"] = do
  dir <- getCurrentDirectory
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  mapM_ checkFileWithDoneHint witFileList
handle ["instance", "import", file, importName] =
  parseFile file
    >>= eitherIO check0
    >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Import, side = Instance} importName)
handle ["runtime", "import", file, importName] =
  parseFile file
    >>= eitherIO check0
    >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Import, side = Runtime} importName)
handle ["instance", mode, file] = do
  case mode of
    "import" ->
      parseFile file
        >>= eitherIO check0
        >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Import, side = Instance} "wasmedge")
    "export" ->
      parseFile file
        >>= eitherIO check0
        >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Export, side = Instance} "wasmedge")
    bad -> putStrLn $ "unknown option: " ++ bad
handle ["runtime", mode, file] =
  case mode of
    "import" ->
      parseFile file
        >>= eitherIO check0
        >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Import, side = Runtime} "wasmedge")
    "export" ->
      parseFile file
        >>= eitherIO check0
        >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = Export, side = Runtime} "wasmedge")
    bad -> putStrLn $ "unknown option: " ++ bad
handle _ = putStrLn "bad usage"

checkFileWithDoneHint :: FilePath -> IO ()
checkFileWithDoneHint file = do
  checkFile file $> ()
  putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line

main :: IO ()
main = do
  args <- getArgs
  handle args
