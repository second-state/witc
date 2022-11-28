module Wit.ParserSpec (spec) where

import Control.Monad
import System.IO
import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec
import Wit.Ast
import Wit.Parser

spec :: Spec
spec = describe "parse wit" $ do
  context "parse file" $ do
    it "types.wit" $ do
      contents <- readFile "test/slight-samples/types.wit"
      parse pWitFile "" `shouldSucceedOn` contents
    it "http-handler.wit" $ do
      contents <- readFile "test/slight-samples/http-handler.wit"
      parse pWitFile "" `shouldSucceedOn` contents
    it "http-types.wit" $ do
      contents <- readFile "test/slight-samples/http-types.wit"
      parse pWitFile "" `shouldSucceedOn` contents
  context "definitions" $ do
    it "resource" $ do
      let input =
            unlines
              [ "resource configs {",
                "  // Obtain an app config store, identifiable through a resource descriptor",
                "  static open: func(name: string) -> expected<configs, error>",
                "  // Get an app configuration given a config store, and an identifiable key",
                "  get: func(key: string) -> expected<payload, error>",
                "  // Set an app configuration given a config store, an identifiable key, and its' value",
                "  set: func(key: string, value: payload) -> expected<unit, error>",
                "}"
              ]
      parse pDefinition "" `shouldSucceedOn` input
    it "function" $ do
      parse pDefinition "" "handle-http: func(req: request) -> expected<response, error>"
        `shouldParse` Func
          ( Function
              Nothing
              "handle-http"
              [("req", User "request")]
              (ExpectedTy (User "response") (User "error"))
          )
  context "type definitions" $ do
    it "type definition: enum" $ do
      parse pDefinition ""
        `shouldSucceedOn` unlines
          [ "enum method {",
            "  get,",
            "  post,",
            "  put,",
            "  delete,",
            "  patch,",
            "  head,",
            "  options,",
            "}"
          ]
    -- type definition check
    it "type defintion: record" $ do
      parse pDefinition "" `shouldSucceedOn` "record person { name: string, email: option<string> }"
      parse pDefinition "" `shouldSucceedOn` "record person { name: string, email: option<string>, }"
    it "type defintion: variant" $ do
      parse pDefinition ""
        `shouldSucceedOn` unlines
          [ "variant error {",
            "  error-with-description(string)",
            "}"
          ]
    it "type defintion: type alias" $ do
      parse pDefinition "" `shouldSucceedOn` "type payload = list<u8>"
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
    it "enum: basic" $ do
      let input =
            unlines
              [ "enum method {",
                "  get,",
                "  post,",
                "  put,",
                "  delete,",
                "  patch,",
                "  head,",
                "  options,",
                "}"
              ]
      parse pEnum "" input `shouldParse` Enum "method" ["get", "post", "put", "delete", "patch", "head", "options"]
