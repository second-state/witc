module Wit.Ast (TypeDefinition (..), Type (..)) where

data TypeDefinition
  = Record String [(String, Type)] -- record event { specversion: string, ty: string }
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
  -- user defined types
  | User String
  deriving (Show, Eq)
