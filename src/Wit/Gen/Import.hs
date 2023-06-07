module Wit.Gen.Import
  ( prettyDefWrap,
    prettyDefExtern,
    toVmWrapper,
  )
where

import Control.Monad.Reader
import Data.Map.Lazy qualified as M
import Prettyprinter
import Wit.Check
import Wit.Gen.Normalization
import Wit.Gen.Type
import Wit.TypeValue

-- runtime
toVmWrapper :: String -> String -> TypeSig -> Reader (M.Map FilePath CheckResult) (Doc a)
toVmWrapper importName name (TyArrow param_list result_ty) = do
  params <-
    mapM
      ( \(p, ty) -> do
          ty' <- genTypeRust ty
          return $ pretty p <+> pretty ":" <+> ty'
      )
      param_list
  result_ty' <- genTypeRust result_ty
  sendArgs <- mapM sendArgument param_list
  return $
    hsep
      [ pretty "fn",
        pretty $ normalizeIdentifier name,
        tupled $ pretty "vm: &wasmedge_sdk::Vm" : params,
        pretty "->",
        result_ty'
      ]
      <+> braces
        ( indent
            4
            ( vsep
                ( [pretty "let id = unsafe { witc_abi::runtime::STATE.new_queue() }; "]
                    ++ sendArgs
                    ++ [ hsep
                           [ pretty "vm.run_func(Some(",
                             dquotes (pretty importName),
                             pretty "), ",
                             dquotes (pretty $ externalConvention name),
                             pretty ", vec![wasmedge_sdk::WasmValue::from_i32(id)]).unwrap();"
                           ],
                         pretty "serde_json::from_str(unsafe { witc_abi::runtime::STATE.read_buffer(id).as_str() }).unwrap()"
                       ]
                )
            )
        )
  where
    sendArgument :: (String, TypeVal) -> Reader (M.Map FilePath CheckResult) (Doc a)
    sendArgument (param_name, _) =
      return $
        pretty $
          "unsafe { witc_abi::runtime::STATE.put_buffer(id, serde_json::to_string(&"
            ++ param_name
            ++ ").unwrap()); }"

-- instance
prettyDefWrap :: String -> TypeSig -> Reader (M.Map FilePath CheckResult) (Doc a)
prettyDefWrap name (TyArrow param_list result_ty) = do
  rty <- genTypeRust result_ty
  ps <- mapM prettyBinder param_list
  sendArgs <- mapM sendArgument param_list
  return $
    pretty "fn"
      <+> pretty (normalizeIdentifier name)
        <> parens (hsep $ punctuate comma ps)
      <+> pretty "->"
      <+> rty
      <+> braces
        ( pretty "unsafe"
            <> braces
              ( line
                  <> indent
                    4
                    ( -- require queue
                      pretty
                        "let id = witc_abi::instance::require_queue();"
                        <> line'
                        <> hsep sendArgs
                        <> line'
                        <> pretty (externalConvention name ++ "(id);")
                        <> line'
                        <> pretty "let mut returns: Vec<String> = vec![];"
                        <> line'
                        <> pretty "serde_json::from_str(witc_abi::instance::read(id).to_string().as_str()).unwrap()"
                    )
                  <> line
              )
        )
  where
    sendArgument :: (String, TypeVal) -> Reader (M.Map FilePath CheckResult) (Doc a)
    sendArgument (param_name, _) =
      return $
        pretty
          ("let r = serde_json::to_string(&" ++ param_name ++ ").unwrap();")
          <> line'
          <> pretty "witc_abi::instance::write(id, r.as_ptr() as usize, r.len());"

    prettyBinder :: (String, TypeVal) -> Reader (M.Map FilePath CheckResult) (Doc a)
    prettyBinder (field_name, ty) = do
      ty' <- genTypeRust ty
      return $ pretty field_name <> pretty ":" <+> ty'

prettyDefExtern :: String -> TypeSig -> Reader (M.Map FilePath CheckResult) (Doc a)
prettyDefExtern (externalConvention -> name) (TyArrow {}) = do
  return $ pretty "fn" <+> pretty name <> pretty "(id: i32);"
