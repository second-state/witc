module Wit.Gen.Import
  ( genInstanceImport,
  )
where

import Data.List (intercalate, partition)
import Wit.Ast
import Wit.Gen.Type

genInstanceImport :: WitFile -> String
genInstanceImport WitFile {definition_list = def_list} =
  let (ty_defs, defs) = partition isTypeDef def_list
   in concatMap genTypeDef ty_defs
        ++ unlines
          [ "extern \"C\" {",
            unlines (map genDef defs),
            "}"
          ]

genDef :: Definition -> String
genDef (SrcPos _ d) = genDef d
genDef (Resource _name _) = "test"
-- TODO: normalize name
genDef (Func (Function _attr name param_list result_ty)) =
  "fn "
    ++ name
    ++ "("
    ++ intercalate ", " (map genBinder param_list)
    ++ ")"
    ++ " -> "
    ++ genType result_ty
    ++ ";"
genDef d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
