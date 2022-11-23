module Wit.ParserSpec (spec) where

import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec
import Wit.Ast
import Wit.Parser

spec :: Spec
spec = describe "parse type definitions" $ do
  context "record" $ do
    it "simple" $ do
      let input = "record person { name: string, email: optional<string>}"
      parse pRecord "" input `shouldParse` (Record "person" [("name", PrimString), ("email", Optional PrimString)])
