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
   in unlines (map genTypeDef ty_defs)
        ++ unlines
          [ "#[link(wasm_import_module = \"wasmedge\")]",
            "extern \"wasm\" {",
            unlines (map genDefExtern defs),
            "}"
          ]
        ++ unlines (map genDefWrap defs)

genDefWrap :: Definition -> String
genDefWrap (SrcPos _ d) = genDefWrap d
genDefWrap (Resource _ _) = undefined
genDefWrap (Func (Function _attr name param_list result_ty)) =
  "fn "
    ++ normalizeIdentifier name
    ++ "("
    ++ intercalate ", " (map genBinder param_list)
    ++ ")"
    ++ " -> "
    ++ genType result_ty
    ++ "{"
    -- unsafe call extern function
    ++ ( "unsafe { extern_"
           ++ normalizeIdentifier name
           ++ "("
           ++ intercalate ", " (map (paramInto . fst) param_list)
           ++ ") }.into()"
       )
    ++ "}"
  where
    paramInto :: String -> String
    paramInto s = s ++ ".into()"
genDefWrap d = error "should not get type definition here: " $ show d

genDefExtern :: Definition -> String
genDefExtern (SrcPos _ d) = genDefExtern d
genDefExtern (Resource _name _) = undefined
genDefExtern (Func (Function _attr name param_list result_ty)) =
  "fn "
    ++ ("extern_" ++ normalizeIdentifier name)
    ++ "("
    ++ intercalate ", " (map genABIBinder param_list)
    ++ ")"
    ++ " -> "
    ++ genABIType result_ty
    ++ ";"
genDefExtern d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
