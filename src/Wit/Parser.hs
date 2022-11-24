module Wit.Parser
  ( pRecord,
    pTypeAlias,
    pVariant,
  )
where

import Control.Monad
import Data.Char
import Data.Void
import Text.Megaparsec hiding (State)
import Text.Megaparsec.Char
import Text.Megaparsec.Char.Lexer qualified as L
import Wit.Ast

type Parser = Parsec Void String

pWitFile :: Parser WitFile
pWitFile = do
  ty_def_list <- many $ withPos pTypeDefinition
  return WitFile { type_definition_list = ty_def_list }

pTypeDefinition :: Parser TypeDefinition
pTypeDefinition =
  try pRecord
  <|> try pTypeAlias
  <|> try pVariant

pRecord, pTypeAlias, pVariant :: Parser TypeDefinition
pRecord = do
  keyword "record"
  record_name <- identifier
  field_list <- braces $ sepEndBy pRecordField (symbol ",")
  return $ Record record_name field_list
  where
    pRecordField :: Parser (String, Type)
    pRecordField = do
      field_name <- identifier
      symbol ":"
      ty <- pType
      return (field_name, ty)
pTypeAlias = do
  keyword "type"
  name <- identifier
  symbol "="
  ty <- pType
  return $ TypeAlias name ty
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


pType :: Parser Type
pType =
  do
    try tupleTy
    <|> try listTy
    <|> try optionalTy
    <|> primitiveTy
  where
    tupleTy, listTy, optionalTy, primitiveTy :: Parser Type
    tupleTy = do
      keyword "tuple"
      TupleTy <$> (angles $ sepBy1 pType (symbol ","))
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
        "i8" -> return PrimI8
        "i16" -> return PrimI16
        "i32" -> return PrimI32
        "i64" -> return PrimI64
        name -> return $ User name

------------
-- helper --
------------
withPos :: Parser TypeDefinition -> Parser TypeDefinition
withPos p = SrcPos <$> getSourcePos <*> p

------------
-- tokens --
------------
lineComment, blockComment :: Parser ()
lineComment = L.skipLineComment "//"
blockComment = empty

whitespace :: Parser ()
whitespace = L.space space1 lineComment blockComment

lexeme :: Parser a -> Parser a
lexeme = L.lexeme whitespace

symbol :: String -> Parser ()
symbol s = L.symbol whitespace s *> return ()

wrap :: String -> String -> (Parser a -> Parser a)
wrap l r = between (symbol l) (symbol r)

parens, brackets, braces, angles :: Parser a -> Parser a
parens = wrap "(" ")"
brackets = wrap "[" "]"
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
