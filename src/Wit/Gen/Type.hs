{- Type & its definition should be the same for any direction, hence, it should be independent -}
module Wit.Gen.Type
  ( genTypeDef,
    genType,
    genBinder,
  )
where

import Data.List (intercalate)
import Wit.Ast

genTypeDef :: Definition -> String
genTypeDef (SrcPos _ d) = genTypeDef d
genTypeDef (Record name fields) =
  "struct "
    ++ name
    ++ " {"
    ++ concatMap ((++) "\n  " . genBinder) fields
    ++ "\n}"
    ++ "\n"
genTypeDef (TypeAlias _name _ty) = "\n"
genTypeDef (Variant _name _cases) = "\n"
genTypeDef (Enum _name _tags) = "\n"
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
genType (Optional ty) = "Option<" ++ genType ty ++ ">"
genType (ListTy ty) = "Vec<" ++ genType ty ++ ">"
genType (ExpectedTy ty ety) = "Result<" ++ genType ty ++ ", " ++ genType ety ++ ">"
genType (TupleTy ty_list) = "(" ++ intercalate ", " (map genType ty_list) ++ ")"
genType (User name) = name
