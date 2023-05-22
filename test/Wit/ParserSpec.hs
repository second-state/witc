module Wit.ParserSpec (spec) where

import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec
import Wit.Parser

spec :: Spec
spec = describe "parse wit" $ do
  context "use statement" $ do
    it "use {a, b, c} from mod" $ do
      parse pUse "" `shouldSucceedOn` "use { a, b, c } from mod"
    it "use * from mod" $ do
      parse pUse "" `shouldSucceedOn` "use * from mod"
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
      parse pDefinition "" `shouldSucceedOn` "handle-http: func(req: request) -> expected<response, error>"
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
      parse pRecord "" `shouldSucceedOn` input
    it "record: cross-line" $ do
      let input =
            unlines
              [ "record person {",
                "  name: string,",
                "  email: option<string>,",
                "  data: option<payload>,",
                "}"
              ]
      parse pRecord "" `shouldSucceedOn` input
    it "record: no fields" $ do
      let input = "record person {}"
      parse pRecord "" `shouldSucceedOn` input
    -- type alias
    it "type alias: payload is list<u8>" $ do
      let input = "type payload = list<u8>"
      parse pTypeAlias "" `shouldSucceedOn` input
    it "type alias: map is a pair list" $ do
      let input = "type map = list<tuple<string, string>>"
      parse pTypeAlias "" `shouldSucceedOn` input
    -- variant
    it "variant: error" $ do
      let input =
            unlines
              [ "variant error {",
                "  error-with-description(string)",
                "}"
              ]
      parse pVariant "" `shouldSucceedOn` input
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
      parse pEnum "" `shouldSucceedOn` input
