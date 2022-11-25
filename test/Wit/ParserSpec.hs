module Wit.ParserSpec (spec) where

import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec
import Wit.Ast
import Wit.Parser

spec :: Spec
spec = describe "parse wit" $ do
  context "type definitions" $ do
    -- type definition check
    it "type defintion: record" $ do
      parse pTypeDefinition "" `shouldSucceedOn` "record person { name: string, email: option<string> }"
      parse pTypeDefinition "" `shouldSucceedOn` "record person { name: string, email: option<string>, }"
    it "type defintion: variant" $ do
      parse pTypeDefinition ""
        `shouldSucceedOn` unlines
          [ "variant error {",
            "  error-with-description(string)",
            "}"
          ]
    it "type defintion: type alias" $ do
      parse pTypeDefinition "" `shouldSucceedOn` "type payload = list<u8>"
    -- record
    it "record: oneline" $ do
      let input = "record person { name: string, email: option<string> }"
      parse pRecord "" input `shouldParse` Record "person" [("name", PrimString), ("email", Optional PrimString)]
    it "record: cross-line" $ do
      let input =
            unlines
              [ "record person {",
                "  name: string,",
                "  email: option<string>,",
                "  data: option<payload>,",
                "}"
              ]
      parse pRecord "" input `shouldParse` Record "person" [("name", PrimString), ("email", Optional PrimString), ("data", Optional $ User "payload")]
    it "record: no fields" $ do
      let input = "record person {}"
      parse pRecord "" input `shouldParse` Record "person" []
    -- type alias
    it "type alias: payload is list<u8>" $ do
      let input = "type payload = list<u8>"
      parse pTypeAlias "" input `shouldParse` TypeAlias "payload" (ListTy PrimU8)
    it "type alias: map is a pair list" $ do
      let input = "type map = list<tuple<string, string>>"
      parse pTypeAlias "" input `shouldParse` TypeAlias "map" (ListTy (TupleTy [PrimString, PrimString]))
    -- variant
    it "variant: error" $ do
      let input =
            unlines
              [ "variant error {",
                "  error-with-description(string)",
                "}"
              ]
      parse pVariant "" input `shouldParse` Variant "error" [("error-with-description", [PrimString])]
