module Wit.Gen.Import
  ( genInstanceImport,
  )
where

import Data.List (intercalate, partition)
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

genInstanceImport :: WitFile -> String
genInstanceImport WitFile {definition_list = def_list} =
  let (ty_defs, defs) = partition isTypeDef def_list
   in concatMap genTypeDef ty_defs
        ++ unlines
          [ "#[link(wasm_import_module = \"wasmedge\")]",
            "extern \"wasm\" {",
            unlines (map genDefExtern defs),
            "}"
          ]
        ++ unlines (map genDefWrap defs)

genDefWrap :: Definition -> String
genDefWrap (SrcPos _ d) = genDefWrap d
genDefWrap (Resource _ _) = ""
genDefWrap (Func (Function _attr name param_list result_ty)) =
  "fn "
    ++ normalizeIdentifier name
    ++ "("
    ++ intercalate ", " (map genBinder param_list)
    ++ ")"
    ++ " -> "
    ++ genType result_ty
    ++ "{"
    ++ ("unsafe { extern_" ++ normalizeIdentifier name ++ "(" ++ intercalate ", " (map fst param_list) ++ ") }")
    ++ "}"
genDefWrap d = error "should not get type definition here: " $ show d

genDefExtern :: Definition -> String
genDefExtern (SrcPos _ d) = genDefExtern d
genDefExtern (Resource _name _) = ""
genDefExtern (Func (Function _attr name param_list result_ty)) =
  "fn "
    ++ ("extern_" ++ normalizeIdentifier name)
    ++ "("
    ++ intercalate ", " (map genBinder param_list)
    ++ ")"
    ++ " -> "
    ++ genType result_ty
    ++ ";"
genDefExtern d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
