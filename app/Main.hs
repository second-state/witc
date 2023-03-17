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
handle ["version"] = putStrLn "0.2.0"
-- validation
handle ["check", file] = checkFileWithDoneHint file
handle ["check"] = do
  dir <- getCurrentDirectory
  witFileList <- filter (".wit" `isSuffixOf`) <$> listDirectory dir
  mapM_ checkFileWithDoneHint witFileList
-- codegen
handle ["instance", "import", file, importName] = codegen file Import Instance importName
handle ["runtime", "import", file, importName] = codegen file Import Runtime importName
handle ["instance", mode, file] = do
  case mode of
    "import" -> codegen file Import Instance "wasmedge"
    "export" -> codegen file Export Instance "wasmedge"
    bad -> putStrLn $ "unknown option: " ++ bad
handle ["runtime", mode, file] =
  case mode of
    "import" -> codegen file Import Runtime "wasmedge"
    "export" -> codegen file Export Runtime "wasmedge"
    bad -> putStrLn $ "unknown option: " ++ bad
handle _ = putStrLn "bad usage"

codegen :: FilePath -> Direction -> Side -> String -> IO ()
codegen file direction side importName =
  parseFile file
    >>= eitherIO check0
    >>= eitherIO (putDoc . prettyFile Config {language = Rust, direction = direction, side = side} importName)

checkFileWithDoneHint :: FilePath -> IO ()
checkFileWithDoneHint file = do
  checkFile file $> ()
  putDoc $ pretty file <+> annotate (color Green) (pretty "OK") <+> line

main :: IO ()
main = do
  args <- getArgs
  handle args
