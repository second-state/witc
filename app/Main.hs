module Main (main) where

import Data.List (isSuffixOf)
import System.Directory
import System.Environment
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Gen.Import
import Wit.Parser

-- cli design
--
--   witc instance import xxx.wit
--   witc runtime export xxx.wit

main :: IO ()
main = do
  args <- getArgs
  handle args

handle :: [String] -> IO ()
handle ["check"] = do
  dir <- getCurrentDirectory
  fileList <- listDirectory dir
  mapM_ checkFile $ filter (".wit" `isSuffixOf`) fileList
handle ["instance", mode, file] = do
  case mode of
    "import" -> do
      ast <- parseFile file
      let result = genInstanceImport ast
      putStrLn result
      -- TODO: output to somewhere file
      return ()
    "export" -> return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle ["runtime", mode, file] =
  case mode of
    "import" -> return ()
    "export" -> do
      ast <- parseFile file
      let _result = genRuntimeExport ast
      -- TODO: output to somewhere file
      return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle _ = putStrLn "bad usage"

genRuntimeExport :: WitFile -> String
genRuntimeExport _ = ""

parseFile :: FilePath -> IO WitFile
parseFile filepath = do
  contents <- readFile filepath
  case parse pWitFile filepath contents of
    -- TODO: use better error raising way
    Left bundle -> error (errorBundlePretty bundle)
    Right wit_file -> return wit_file

checkFile :: FilePath -> IO ()
checkFile filepath = do
  wit_file <- parseFile filepath
  r <- check0 wit_file
  case r of
    -- TODO: hint source code via position
    Left (msg, _pos) -> putStrLn msg
    Right () -> return ()
