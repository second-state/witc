module Wit.CheckSpec (spec) where

import Control.Monad.Except
import Control.Monad.State
import Data.Map.Lazy qualified as Map
import Test.Hspec
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Parser

check' :: WitFile -> ExceptT CheckError IO WitFile
check' wit_file = do
  evalStateT (check Map.empty wit_file) []

spec :: Spec
spec = describe "check wit" $ do
  context "check definition" $ do
    it "should report undefined type" $ do
      contents <- readFile "test/slight-samples/bad-types.wit"
      case runParser pWitFile "" contents of
        Left _bundle -> return ()
        Right wit_file -> do
          r <- runExceptT (check' wit_file)
          case r of
            Left _ -> return ()
            Right _ -> expectationFailure "checker should find out undefined type!"
