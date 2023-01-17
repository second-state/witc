{-
cli design

    witc instance import xxx.wit
    witc runtime export xxx.wit
-}
module Main (main) where

import Control.Monad
import Data.Functor
import Data.List (isSuffixOf)
import Prettyprinter.Render.Text
import System.Directory
import System.Environment
import System.Exit (exitSuccess)
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Gen
import Wit.Parser (ParserError, pWitFile)

main :: IO ()
main = do
  args <- getArgs
  handle args

handle :: [String] -> IO ()
handle ["check", file] = checkFile file $> ()
handle ["check"] = do
  dir <- getCurrentDirectory
  fileList <- listDirectory dir
  mapM_ checkFile $ filter (".wit" `isSuffixOf`) fileList
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

parseFile :: FilePath -> IO (Either FuseError WitFile)
parseFile filepath = do
  content <- readFile filepath
  case parse pWitFile filepath content of
    Left e -> return $ Left (PErr e)
    Right ast -> return $ Right ast

checkFile :: FilePath -> IO WitFile
checkFile = parseFile >=> eitherIO (check0 >=> eitherIO return)

eitherIO :: Show e => (a -> IO b) -> Either e a -> IO b
eitherIO f = \case
  Left e -> print e *> exitSuccess
  Right a -> f a

data FuseError
  = PErr ParserError
  | CErr CheckError

instance Show FuseError where
  show (PErr bundle) = errorBundlePretty bundle
  show (CErr ce) = show ce
