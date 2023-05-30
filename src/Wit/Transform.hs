module Wit.Transform
  ( transformDefinitions,
  )
where

import Wit.Ast

transformDefinitions :: [Definition] -> [Definition]
transformDefinitions = expandResource

expandResource :: [Definition] -> [Definition]
expandResource (SrcPos _ d : rest) = expandResource (d : rest)
expandResource (Resource name funcs : rest) =
  TypeAlias name PrimU32 : map convF funcs ++ expandResource rest
  where
    rename :: String -> String
    rename fn_name = name ++ "_" ++ fn_name
    convF :: (Attr, Function) -> Definition
    -- e.g.
    -- `static open: func(name: string) -> expected<keyvalue, keyvalue-error>`
    -- ~> out of resource
    -- `keyvalue_open: func(name: string) -> expected<keyvalue, keyvalue-error>`
    convF (Static, Function (rename -> n) ps rt) = Func $ Function n ps rt
    -- e.g.
    -- `get: func(key: string) -> expected<list<u8>, keyvalue-error> `
    -- ~> out of resource
    -- `get: func(handle: keyvalue, key: string) -> expected<list<u8>, keyvalue-error> `
    convF (Member, Function (rename -> n) ps rt) = Func $ Function n (("handle", Defined name) : ps) rt
expandResource (def : rest) = def : expandResource rest
expandResource [] = []
