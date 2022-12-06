module Wit.Parser
  ( -- parser error for this module
    ParserError,
    -- file level parser
    pWitFile,
    -- Use statement
    pUse,
    -- Definition
    pDefinition,
    -- define object
    pResource,
    pFunc,
    -- define type
    pRecord,
    pTypeAlias,
    pVariant,
    pEnum,
  )
where

import Control.Monad
import Data.Char
import Data.Functor
import Data.Void
import Text.Megaparsec hiding (State)
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L
import Wit.Ast

type Parser = Parsec Void String

type ParserError = ParseErrorBundle String Void

pWitFile :: Parser WitFile
pWitFile = do
  us <- many $ lexeme (withPos SrcPosUse pUse)
  ds <- many $ lexeme (withPos SrcPos pDefinition)
  return WitFile {use_list = us, definition_list = ds}

pUse :: Parser Use
pUse = do
  keyword "use"
  all_syntax <- optional $ symbol "*"
  case all_syntax of
    Just _ -> do
      keyword "from"
      UseAll <$> identifier
    Nothing -> do
      id_list <- braces $ sepEndBy identifier (symbol ",")
      keyword "from"
      Use id_list <$> identifier

pDefinition :: Parser Definition
pDefinition =
  choice
    [ pRecord,
      pTypeAlias,
      pVariant,
      pEnum,
      pResource,
      pFunc
    ]

-- object definition
pResource, pFunc :: Parser Definition
pResource = do
  keyword "resource"
  Resource <$> identifier <*> braces (many pFunction)
pFunc = Func <$> pFunction

pFunction :: Parser Function
pFunction = do
  attr <- optional $ keyword "static"
  fn_name <- identifier
  symbol ":"
  keyword "func"
  Function
    ( case attr of
        Just _ -> Just Static
        Nothing -> Nothing
    )
    fn_name
    <$> parens (sepEndBy pParam (symbol ","))
    <*> pResultType
  where
    pParam :: Parser (String, Type)
    pParam = (,) <$> (identifier <* symbol ":") <*> pType
    pResultType :: Parser Type
    pResultType = symbol "->" *> pType

-- type definition
pRecord, pTypeAlias, pVariant, pEnum :: Parser Definition
pRecord = do
  keyword "record"
  record_name <- identifier
  field_list <- braces $ sepEndBy pRecordField (symbol ",")
  return $ Record record_name field_list
  where
    pRecordField :: Parser (String, Type)
    pRecordField = (,) <$> (identifier <* symbol ":") <*> pType
pTypeAlias = do
  keyword "type"
  name <- identifier
  symbol "="
  TypeAlias name <$> pType
pVariant = do
  keyword "variant"
  name <- identifier
  case_list <- braces $ sepEndBy pVariantCase (symbol ",")
  return $ Variant name case_list
  where
    -- tag-name "(" type ("," type)* ")"
    pVariantCase :: Parser (String, [Type])
    pVariantCase = do
      tag_name <- identifier
      type_list <- parens $ sepBy pType (symbol ",")
      return (tag_name, type_list)
pEnum = do
  keyword "enum"
  name <- identifier
  case_list <- braces $ sepEndBy identifier (symbol ",")
  return $ Enum name case_list

pType :: Parser Type
pType =
  withPos
    SrcPosType
    ( choice
        [expectedTy, tupleTy, listTy, optionalTy, primitiveTy]
        <?> "<type>"
    )
  where
    expectedTy, tupleTy, listTy, optionalTy, primitiveTy :: Parser Type
    expectedTy = do
      keyword "expected"
      (a, b) <- angles $ (,) <$> pType <*> (symbol "," *> pType)
      return $ ExpectedTy a b
    tupleTy = do
      keyword "tuple"
      TupleTy <$> angles (sepBy1 pType (symbol ","))
    listTy = do
      keyword "list"
      ListTy <$> angles pType
    optionalTy = do
      keyword "option"
      Optional <$> angles pType
    primitiveTy = do
      name <- identifier
      case name of
        "string" -> return PrimString
        "u8" -> return PrimU8
        "u16" -> return PrimU16
        "u32" -> return PrimU32
        "u64" -> return PrimU64
        "s8" -> return PrimI8
        "s16" -> return PrimI16
        "s32" -> return PrimI32
        "s64" -> return PrimI64
        "char" -> return PrimChar
        "f32" -> return PrimF32
        "f64" -> return PrimF64
        name' -> return $ User name'

------------
-- helper --
------------
withPos :: (SourcePos -> a -> a) -> Parser a -> Parser a
withPos c p = c <$> getSourcePos <*> p

------------
-- tokens --
------------
lineComment, blockComment :: Parser ()
lineComment = L.skipLineComment "//"
blockComment = L.skipBlockComment "/*" "*/"

whitespace :: Parser ()
whitespace = L.space space1 lineComment blockComment

lexeme :: Parser a -> Parser a
lexeme = L.lexeme whitespace

symbol :: String -> Parser ()
symbol s = L.symbol whitespace s $> ()

wrap :: String -> String -> (Parser a -> Parser a)
wrap l r = between (symbol l) (symbol r)

parens, braces, angles :: Parser a -> Parser a
parens = wrap "(" ")"
braces = wrap "{" "}"
angles = wrap "<" ">"

keyword :: String -> Parser ()
keyword kw = do
  _ <- string kw <?> ("keyword: `" ++ kw ++ "`")
  (takeWhile1P Nothing isAlphaNum *> empty) <|> whitespace

identifier :: Parser String
identifier = do
  x <- takeWhile1P Nothing isValidChar
  guard (not (isKeyword x))
  x <$ whitespace
  where
    isValidChar :: Char -> Bool
    isValidChar '-' = True
    isValidChar c = isAlphaNum c

isKeyword :: String -> Bool
isKeyword "record" = True
isKeyword "optional" = True
isKeyword _ = False
