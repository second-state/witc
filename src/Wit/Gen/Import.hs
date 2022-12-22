module Wit.Gen.Import
  ( renderInstanceImport,
  )
where

import Data.List (partition)
import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Gen.Normalization
import Wit.Gen.Type

renderInstanceImport :: WitFile -> IO ()
renderInstanceImport f = putDoc $ prettyFile f

prettyFile :: WitFile -> Doc a
prettyFile
  ( WitFile
      { definition_list = def_list
      }
    ) =
    let (ty_defs, defs) = partition isTypeDef def_list
     in vsep (map prettyTypeDef ty_defs)
          <+> line
          <+> vsep
            [ pretty "#[link(wasm_import_module = \"wasmedge\")]",
              pretty "extern \"wasm\" {",
              vsep (map prettyDefExtern defs),
              pretty "}"
            ]
          <+> line
          <+> vsep (map prettyDefWrap defs)

prettyDefWrap :: Definition -> Doc a
prettyDefWrap (SrcPos _ d) = prettyDefWrap d
prettyDefWrap (Resource _ _) = undefined
prettyDefWrap (Func (Function _attr name param_list result_ty)) =
  hsep (map pretty ["fn", normalizeIdentifier name])
    <+> parens (hsep $ punctuate comma (map prettyBinder param_list))
    <+> hsep [pretty "->", prettyType result_ty]
    <+> braces
      ( -- unsafe call extern function
        hsep
          [ pretty $ "unsafe { extern_" ++ normalizeIdentifier name,
            pretty "(",
            hsep $ punctuate comma (map (paramInto . fst) param_list),
            pretty ") }.into()"
          ]
      )
  where
    paramInto :: String -> Doc a
    paramInto s = pretty $ s ++ ".into()"
prettyDefWrap d = error "should not get type definition here: " $ show d

prettyDefExtern :: Definition -> Doc a
prettyDefExtern (SrcPos _ d) = prettyDefExtern d
prettyDefExtern (Resource _name _) = undefined
prettyDefExtern (Func (Function _attr name param_list result_ty)) =
  hsep (map pretty ["fn", "extern_" ++ normalizeIdentifier name])
    <+> parens (hsep $ punctuate comma (map prettyABIBinder param_list))
    <+> pretty "->"
    <+> prettyABIType result_ty
    <+> pretty ";"
prettyDefExtern d = error "should not get type definition here: " $ show d

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Resource _ _) = False
isTypeDef (Func _) = False
isTypeDef _ = True
