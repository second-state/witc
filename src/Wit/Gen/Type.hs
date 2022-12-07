{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( genTypeDef,
    genType,
    genBinder,
  )
where

import Data.List (intercalate)
import Wit.Ast
import Wit.Gen.Normalization

genTypeDef :: Definition -> String
genTypeDef (SrcPos _ d) = genTypeDef d
genTypeDef (Record name fields) =
  "struct "
    ++ normalizeIdentifier name
    ++ " {"
    ++ intercalate "," (map genBinder fields)
    ++ "\n}\n"
genTypeDef (TypeAlias _name _ty) = "\n"
genTypeDef (Variant name cases) =
  "enum "
    ++ normalizeIdentifier name
    ++ " {"
    ++ intercalate "," (map genCase cases)
    ++ "}\n"
  where
    genCase :: (String, [Type]) -> String
    genCase (case_name, []) = case_name
    genCase (case_name, ts) =
      unwords
        [ case_name,
          "(",
          intercalate "," (map boxType ts),
          ")"
        ]
    boxType :: Type -> String
    boxType (SrcPosType _ ty) = boxType ty
    boxType (User recur_name) =
      if name == recur_name
        then "Box<" ++ recur_name ++ ">"
        else name
    boxType ty = genType ty
genTypeDef (Enum name tags) =
  "enum "
    ++ normalizeIdentifier name
    ++ " {"
    ++ intercalate "," tags
    ++ "}\n"
genTypeDef d = error "should not get type definition here: " $ show d

genBinder :: (String, Type) -> String
genBinder (field_name, ty) = field_name ++ ": " ++ genType ty

genType :: Type -> String
genType (SrcPosType _ ty) = genType ty
genType PrimString = "String"
genType PrimU8 = "u8"
genType PrimU16 = "u16"
genType PrimU32 = "u32"
genType PrimU64 = "u64"
genType PrimI8 = "i8"
genType PrimI16 = "i16"
genType PrimI32 = "i32"
genType PrimI64 = "i64"
genType PrimChar = "char"
genType PrimF32 = "f32"
genType PrimF64 = "f64"
genType (Optional ty) = unwords ["Option<", genType ty, ">"]
genType (ListTy ty) = unwords ["Vec<", genType ty, ">"]
genType (ExpectedTy ty ety) =
  unwords ["Result<", genType ty, ",", genType ety, ">"]
genType (TupleTy ty_list) =
  unwords ["(", intercalate ", " (map genType ty_list), ")"]
genType (User name) = name
