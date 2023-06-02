module Wit.TypeValue
  ( TypeVal (..),
  )
where

data TypeVal
  = TyString
  | TyUnit
  | TyU8
  | TyU16
  | TyU32
  | TyU64
  | TyI8
  | TyI16
  | TyI32
  | TyI64
  | TyChar
  | TyF32
  | TyF64
  | TyOptional TypeVal
  | TyList TypeVal
  | TyExpected TypeVal TypeVal
  | -- conceptual product type: A × B × C
    TyTuple [TypeVal]
  | -- conceptual sum type: A + B + C
    -- we record the name of the sum type to handle recursion in it
    TySum String [TypeVal]
  | -- checker should ensure reference is linked to defined type
    --
    -- we have two modes
    -- 1. flatten type: wasmedge plugin codegen
    -- 2. recursive type: witc component codegen
    --
    -- flatten type disallowed recursive, and hence we cannot resolve type reference directly, so we need this
    TyRef String
