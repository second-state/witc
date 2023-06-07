module Wit.CheckSpec (spec) where

import Control.Monad.Except
import System.FilePath
import Test.Hspec
import Wit.Check

specFile :: FilePath -> IO ()
specFile file = do
  r <- runExceptT $ checkFile (takeDirectory file) (takeFileName file)
  case r of
    Left _ -> return ()
    Right _ -> expectationFailure "checker should find some errors"

spec :: Spec
spec = describe "check wit" $ do
  context "check definition" $ do
    it "`bad-types` should report undefined type" $ do
      specFile "test/data/bad-types.wit"
    it "`bad-types2` should report undefined type" $ do
      specFile "test/data/bad-types2.wit"
    it "`func-using-missing-type` should report undefined type" $ do
      specFile "test/data/func-using-missing-type.wit"
  context "check dependencies" $ do
    it "should report no such file" $ do
      specFile "test/data/bad-import.wit"
    it "should report no such definition in the dependency" $ do
      specFile "test/data/bad-import2.wit"
