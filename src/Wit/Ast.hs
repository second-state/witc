module Wit.Ast
  ( WitFile (..),
    TypeDefinition (..),
    Type (..),
  )
where

import Text.Megaparsec

newtype WitFile = WitFile
  { type_definition_list :: [TypeDefinition]
  }

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
  | TupleTy [Type]
  | User String -- user defined types
  deriving (Show, Eq)
