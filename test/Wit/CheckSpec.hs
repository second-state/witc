module Wit.CheckSpec (spec) where

import Test.Hspec
import Text.Megaparsec
import Wit.Check
import Wit.Parser

spec :: Spec
spec = describe "check wit" $ do
  context "check definition" $ do
    it "should report undefined type" $ do
      contents <- readFile "test/slight-samples/bad-types.wit"
      case runParser pWitFile "" contents of
        Left bundle -> putStrLn $ "fail: " ++ errorBundlePretty bundle
        Right wit_file -> do
          r <- check0 wit_file
          case r of
            Left (_msg, _pos) -> return ()
            Right _ -> expectationFailure "checker should find out undefined type!"
