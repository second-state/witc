{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
-}
module Main (main) where

import Control.Monad
import Control.Monad.Primitive
import Data.List (isSuffixOf)
import System.Directory
import System.Environment
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Gen.Import
import Wit.Parser

main :: IO ()
main = do
  args <- getArgs
  handle args

handle :: [String] -> IO ()
handle ["check", file] = checkFile file
handle ["check"] = do
  dir <- getCurrentDirectory
  fileList <- listDirectory dir
  mapM_ checkFile $ filter (".wit" `isSuffixOf`) fileList
handle ["instance", mode, file] = do
  case mode of
    "import" -> do
      parseFile file
        -- TODO: output to somewhere file
        >>= displayErr (putStrLn . genInstanceImport) errorBundlePretty
      return ()
    "export" -> return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle ["runtime", mode, file] =
  case mode of
    "import" -> return ()
    "export" -> do
      parseFile file
        -- TODO: output to somewhere file
        >>= displayErr (putStrLn . genRuntimeExport) errorBundlePretty
      return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle _ = putStrLn "bad usage"

genRuntimeExport :: WitFile -> String
genRuntimeExport _ = ""

parseFile :: FilePath -> IO (Either ParserError WitFile)
parseFile filepath = parse pWitFile filepath <$> readFile filepath

checkFile :: FilePath -> IO ()
checkFile = parseFile >=> displayErr (check0 >=> displayErr touch show) errorBundlePretty

displayErr :: (a -> IO ()) -> (e -> String) -> Either e a -> IO ()
displayErr f showE = \case
  Left e -> putStrLn $ showE e
  Right a -> f a
