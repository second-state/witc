module Wit.Parser
  ( -- file level parser
    pWitFile,
    -- use statement
    pUse,
    -- definition
    pDefinition,
    pFunc,
    -- type definition
    pTypeDefinition,
    pRecord,
    pTypeAlias,
    pVariant,
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

pWitFile :: Parser WitFile
pWitFile = do
  use_list <- many pUse
  ty_def_list <- many $ withPos pTypeDefinition
  return WitFile {use_list = use_list, type_definition_list = ty_def_list}

pUse :: Parser Use
pUse = do
  pos <- getSourcePos
  keyword "use"
  id_list <- braces $ sepEndBy identifier (symbol ",")
  keyword "from"
  Use pos id_list <$> identifier

pDefinition :: Parser Definition
pDefinition = choice [pFunc]

-- Example code
--
-- ```
-- handle-http: func(req: request) -> expected<response, error>
-- ```
pFunc :: Parser Definition
pFunc = do
  fn_name <- identifier
  symbol ":"
  keyword "func"
  Function fn_name
    <$> parens (sepEndBy pParam (symbol ","))
    <*> pResultType
  where
    pParam :: Parser (String, Type)
    pParam = (,) <$> (identifier <* symbol ":") <*> pType
    pResultType :: Parser Type
    pResultType = symbol "->" *> pType

pTypeDefinition :: Parser TypeDefinition
pTypeDefinition =
  choice
    [ pRecord,
      pTypeAlias,
      pVariant
    ]

pRecord, pTypeAlias, pVariant :: Parser TypeDefinition
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

pType :: Parser Type
pType =
  choice
    [ expectedTy,
      tupleTy,
      listTy,
      optionalTy,
      primitiveTy
    ]
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
        name' -> return $ User name'

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
symbol s = L.symbol whitespace s $> ()

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
