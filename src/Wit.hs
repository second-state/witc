module Wit
  ( parseFile,
    check0,
    checkFile,
    eitherIO,
    prettyFile,
    Config (..),
    SupportedLanguage (..),
    Direction (..),
    Side (..),
  )
where

import Control.Monad
import System.Exit (exitSuccess)
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Gen
import Wit.Parser (ParserError, pWitFile)

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
