module Wit.Parser
  ( pRecord,
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

pRecord :: Parser TypeDefinition
pRecord = do
  keyword "record"
  record_name <- identifier
  field_list <- braces $ sepBy1 pRecordField (symbol ",")
  return $ Record record_name field_list
  where
    pRecordField :: Parser (String, Type)
    pRecordField = do
      field_name <- identifier
      symbol ":"
      ty <- pType
      return (field_name, ty)

pType :: Parser Type
pType =
  do
    try optionalTy
    <|> primitiveTy
  where
    optionalTy :: Parser Type
    optionalTy = do
      keyword "optional"
      symbol "<"
      ty <- pType
      symbol ">"
      return $ Optional ty
    primitiveTy :: Parser Type
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
        _ -> error "not primitive"

------------
-- tokens --
------------
lineComment, blockComment :: Parser ()
lineComment = L.skipLineComment "//"
blockComment = empty

scn, sc :: Parser ()
scn = L.space space1 lineComment blockComment
sc = L.space hspace1 lineComment blockComment

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: String -> Parser ()
symbol s = L.symbol sc s *> return ()

parens, brackets, braces :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")
brackets = between (symbol "[") (symbol "]")
braces = between (symbol "{") (symbol "}")

keyword :: String -> Parser ()
keyword kw = do
  _ <- string kw
  (takeWhile1P Nothing isAlphaNum *> empty) <|> scn

identifier :: Parser String
identifier = do
  x <- takeWhile1P Nothing isValidChar
  guard (not (isKeyword x))
  x <$ scn
  where
    isValidChar :: Char -> Bool
    isValidChar '-' = True
    isValidChar c = isAlphaNum c

isKeyword :: String -> Bool
isKeyword "record" = True
isKeyword "optional" = True
isKeyword _ = False
