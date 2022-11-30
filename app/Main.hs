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
        >>= displayIOLeft errorBundlePretty (putStrLn . genInstanceImport)
      return ()
    "export" -> return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle ["runtime", mode, file] =
  case mode of
    "import" -> return ()
    "export" -> do
      parseFile file
        -- TODO: output to somewhere file
        >>= displayIOLeft errorBundlePretty (putStrLn . genRuntimeExport)
      return ()
    bad -> putStrLn $ "unknown option: " ++ bad
handle _ = putStrLn "bad usage"

genRuntimeExport :: WitFile -> String
genRuntimeExport _ = ""

parseFile :: FilePath -> IO (Either ParserError WitFile)
parseFile filepath = parse pWitFile filepath <$> readFile filepath

checkFile :: FilePath -> IO ()
checkFile = parseFile >=> displayIOLeft errorBundlePretty (check0 >=> displayIOLeft show touch)

displayIOLeft :: (e -> String) -> (a -> IO ()) -> Either e a -> IO ()
displayIOLeft showE f = \case
  Left e -> putStrLn $ showE e
  Right a -> f a
