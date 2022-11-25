module Wit.Ast
  ( WitFile (..),
    Use (..),
    Definition (..),
    TypeDefinition (..),
    Type (..),
  )
where

import Text.Megaparsec

data WitFile = WitFile
  { use_list :: [Use],
    type_definition_list :: [TypeDefinition]
  }
  deriving (Show, Eq)

data Use = Use SourcePos [String] String
  deriving (Show, Eq)

data Definition
  = Function String [(String, Type)] Type
  | Resource -- place holder for `resource`
  deriving (Show, Eq)

data TypeDefinition
  = SrcPos SourcePos TypeDefinition
  | Record String [(String, Type)] -- record event { specversion: string, ty: string }
  | TypeAlias String Type -- type payload = list<u8>
  | Variant String [(String, [Type])]
  deriving (Show, Eq)

data Type
  = PrimString
  | PrimU8
  | PrimU16
  | PrimU32
  | PrimU64
  | PrimI8
  | PrimI16
  | PrimI32
  | PrimI64
  | Optional Type
  | ListTy Type
  | ExpectedTy Type Type
  | TupleTy [Type]
  | User String -- user defined types
  deriving (Show, Eq)
