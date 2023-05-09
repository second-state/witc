module Wit.CheckSpec (spec) where

import Control.Monad.Except
import Test.Hspec
import Text.Megaparsec
import Wit.Ast
import Wit.Check
import Wit.Parser
import Data.Map.Lazy qualified as Map

check' :: WitFile -> ExceptT CheckError IO WitFile
check' = check Map.empty

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
