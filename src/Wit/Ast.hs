module Wit.Ast
  ( WitFile (..),
    Use (..),
    Definition (..),
    Function (..),
    Attr (..),
    Type (..),
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
    Use [String] String
  | -- use * from mod
    UseAll String
  deriving (Show, Eq)

data Definition
  = SrcPos SourcePos Definition
  | Resource String [Function]
  | Func Function
  | Record String [(String, Type)] -- record event { specversion: string, ty: string }
  | TypeAlias String Type -- type payload = list<u8>
  | Variant String [(String, [Type])]
  | Enum String [String]
  deriving (Show, Eq)

data Function = Function (Maybe Attr) String [(String, Type)] Type
  deriving (Show, Eq)

data Attr = Static
  deriving (Show, Eq)

instance Eq Type where
  (SrcPosType _ a) == (SrcPosType _ b) = a == b
  PrimString == PrimString = True
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
  TupleTy as == TupleTy bs = eqTyList as bs
  User a == User b = a == b
  _ == _ = False

eqTyList :: [Type] -> [Type] -> Bool
eqTyList [] [] = True
eqTyList (a : as) (b : bs) = a == b && eqTyList as bs
eqTyList _ _ = False

data Type
  = SrcPosType SourcePos Type
  | PrimString
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
  | User String -- user defined types
  deriving (Show)
