module Wit.Ast
  ( WitFile (..),
    Use (..),
    Definition (..),
    Function (..),
    Attr (..),
    Type (..),
    dependencies,
  )
where

import Text.Megaparsec (SourcePos)

data WitFile = WitFile
  { use_list :: [Use],
    definition_list :: [Definition]
  }
  deriving (Show, Eq)

data Use
  = SrcPosUse SourcePos Use
  | -- use { a, b, c } from mod
    Use [(SourcePos, String)] String
  | -- use * from mod
    UseAll String
  deriving (Show, Eq)

dependencies :: [Use] -> [FilePath]
dependencies [] = []
dependencies (SrcPosUse _ use : xs) = dependencies (use : xs)
dependencies (UseAll path : xs) = path : dependencies xs
dependencies (Use _ path : xs) = path : dependencies xs

data Definition
  = SrcPos SourcePos Definition
  | Resource String [(Attr, Function)]
  | Func Function
  | -- record event { specversion: string, ty: string }
    Record String [(String, Type)]
  | -- type payload = list<u8>
    TypeAlias String Type
  | Variant String [(String, [Type])]
  | Enum String [String]
  deriving (Show, Eq)

data Function = Function String [(String, Type)] Type
  deriving (Show, Eq)

data Attr
  = Static
  | Member
  deriving (Show, Eq)

data Type
  = SrcPosType SourcePos Type
  | PrimString
  | PrimUnit
  | PrimU8
  | PrimU16
  | PrimU32
  | PrimU64
  | PrimI8
  | PrimI16
  | PrimI32
  | PrimI64
  | PrimChar
  | PrimF32
  | PrimF64
  | Optional Type
  | ListTy Type
  | ExpectedTy Type Type
  | TupleTy [Type]
  | -- If we parsed something unknown, it probably is a user defined type
    -- and hence, we will use checker to reject undefined type errors
    Defined String
  deriving (Show)

instance Eq Type where
  (SrcPosType _ a) == (SrcPosType _ b) = a == b
  PrimString == PrimString = True
  PrimUnit == PrimUnit = True
  PrimU8 == PrimU8 = True
  PrimU16 == PrimU16 = True
  PrimU32 == PrimU32 = True
  PrimU64 == PrimU64 = True
  PrimI8 == PrimI8 = True
  PrimI16 == PrimI16 = True
  PrimI32 == PrimI32 = True
  PrimI64 == PrimI64 = True
  PrimChar == PrimChar = True
  PrimF32 == PrimF32 = True
  PrimF64 == PrimF64 = True
  Optional a == Optional b = a == b
  ListTy a == ListTy b = a == b
  ExpectedTy a1 b1 == ExpectedTy a2 b2 = a1 == a2 && b1 == b2
  TupleTy as == TupleTy bs = as == bs
  Defined a == Defined b = a == b
  _ == _ = False
