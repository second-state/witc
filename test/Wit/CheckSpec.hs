module Wit.CheckSpec (spec) where

import Control.Monad.Except
import Control.Monad.Reader
import Control.Monad.State
import System.FilePath
import Test.Hspec
import Wit.Ast
import Wit.Check

check' :: FilePath -> WitFile -> ExceptT CheckError IO WitFile
check' dirpath wit_file = do
  runReaderT (evalStateT (check wit_file) emptyCheckState) dirpath

checkFile :: FilePath -> FilePath -> ExceptT CheckError IO WitFile
checkFile dirpath filepath = do
  ast <- runReaderT (parseFile filepath) dirpath
  check' dirpath ast

specFile :: FilePath -> IO ()
specFile file = do
  r <- runExceptT $ checkFile (takeDirectory file) (takeFileName file)
  case r of
    Left _ -> return ()
    Right _ -> expectationFailure "checker should find out undefined type!"

spec :: Spec
spec = describe "check wit" $ do
  context "check definition" $ do
    it "should report undefined type" $ do
      specFile "test/data/bad-types.wit"
    it "should report undefined type" $ do
      specFile "test/data/bad-types2.wit"
    it "should report undefined type" $ do
      specFile "test/data/func-using-missing-type.wit"
  context "check dependencies" $ do
    it "should report no such file" $ do
      specFile "test/data/bad-import.wit"
    it "should report no such definition in the dependency" $ do
      specFile "test/data/bad-import2.wit"
