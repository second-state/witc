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
    it "should report undefined type" $ do
      contents <- readFile "test/slight-samples/bad-types.wit"
      case runParser pWitFile "" contents of
        Left err -> putStrLn "fail"
        Right wit_file -> do
          r <- check0 wit_file
          case r of
            Left (_msg, _pos) -> return ()
            Right _ -> expectationFailure "checker should find out undefined type!"
