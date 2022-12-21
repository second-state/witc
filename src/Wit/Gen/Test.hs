module Wit.Gen.Test
  ( renderFile,
  )
where

import Prettyprinter
import Prettyprinter.Render.Text
import Wit.Ast
import Wit.Gen.Type

renderFile :: WitFile -> IO ()
renderFile f = putDoc $ prettyFile f

prettyFile :: WitFile -> Doc a
prettyFile
  ( WitFile
      { use_list = use_list,
        definition_list = definition_list
      }
    ) = vsep (map prettyDef definition_list)

prettyDef :: Definition -> Doc a
prettyDef (SrcPos _ d) = prettyDef d
prettyDef (Func _) = undefined
prettyDef (Resource _ _) = undefined
prettyDef (Record name fields) =
  pretty "record"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map prettyField fields))
          <+> line
      )
  where
    prettyField :: (String, Type) -> Doc a
    prettyField (n, ty) = hsep $ map pretty [n, ":", genType ty]
prettyDef (TypeAlias name ty) = hsep $ map pretty ["type", name, "=", genType ty, ";"]
prettyDef (Variant name cases) =
  pretty "enum"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map prettyCase cases))
          <+> line
      )
  where
    prettyCase :: (String, [Type]) -> Doc a
    prettyCase (n, tys) = pretty n <+> parens (hsep (punctuate comma (map (pretty . genType) tys)))
prettyDef (Enum name cases) =
  pretty "enum"
    <+> pretty name
    <+> braces
      ( line
          <+> indent 4 (vsep $ punctuate comma (map pretty cases))
          <+> line
      )
