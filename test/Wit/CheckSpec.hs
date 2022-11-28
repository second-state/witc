module Wit.CheckSpec (spec) where

import Control.Applicative
import Control.Monad
import Control.Monad.State
import Control.Monad.Trans.Except
import System.IO
import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec
import Wit.Check
import Wit.Parser

spec :: Spec
spec = describe "check wit" $ do
  context "check definition" $ do
    it "bad type" $ do
      contents <- readFile "test/slight-samples/bad-types.wit"
      case runParser pWitFile "" contents of
        Left err -> putStrLn "fail"
        Right wit_file -> case check0 wit_file of
          Left (msg, _) -> expectationFailure msg
          Right _ -> return ()
