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
      let input = "record person { name: string, email: optional<string> }"
      parse pRecord "" input `shouldParse` Record "person" [("name", PrimString), ("email", Optional PrimString)]
    it "cross-line" $ do
      let input =
            unlines
              [ "record person {",
                "  name: string,",
                "  email: optional<string>",
                "}"
              ]
      parse pRecord "" input `shouldParse` Record "person" [("name", PrimString), ("email", Optional PrimString)]
    it "no fields record" $ do
      let input = "record person {}"
      parse pRecord "" input `shouldParse` Record "person" []
  context "type alias" $ do
    it "payload is list<u8>" $ do
      let input = "type payload = list<u8>"
      parse pTypeAlias "" input `shouldParse` TypeAlias "payload" (ListTy PrimU8)
    it "map is a pair list" $ do
      let input = "type map = list<tuple<string, string>>"
      parse pTypeAlias "" input `shouldParse` TypeAlias "map" (ListTy (TupleTy [PrimString, PrimString]))
  context "variant" $ do
    it "an error variant" $ do
      let input = unlines
                    [ "variant error {",
	                    "  error-with-description(string)",
                      "}"
                    ]
      parse pVariant "" input `shouldParse` Variant "error" [("error-with-description", [PrimString])]
