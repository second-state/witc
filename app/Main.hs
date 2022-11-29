module Main (main) where

import Data.List
import System.Directory
import System.Environment
import Text.Megaparsec
import Wit.Check
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
  mapM_ checkFile $ filter (\s -> ".wit" `isSuffixOf` s) fileList
  return ()
handle ["instance", mode, file] = do
  -- ast <- parse file
  -- output <- gen mode ast
  putStrLn "TODO"
handle ["runtime", mode, file] = putStrLn "TODO"
handle _ = putStrLn "bad usage"

checkFile :: FilePath -> IO ()
checkFile filepath = do
  contents <- readFile filepath
  case parse pWitFile filepath contents of
    Left bundle -> putStr (errorBundlePretty bundle)
    Right wit_file -> do
      r <- check0 wit_file
      case r of
        -- TODO: hint source code via position
        Left (msg, _pos) -> putStrLn msg
        Right () -> return ()
