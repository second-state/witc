module Wit.Gen.Plugin
  ( genPluginRust,
  )
where

-- idea: only generate func definition
-- the type definition should be dropped
import Data.List (partition)
import Prettyprinter
import Wit.Ast

genPluginRust :: WitFile -> Doc a
genPluginRust wit_file =
  let (_, defs) = partition isTypeDef wit_file.definition_list
   in vsep (map convertFunc defs)

convertFunc :: Definition -> Doc a
convertFunc (Func (Function name param_list _result_ty)) =
  pretty "done"
convertFunc _ = mempty

isTypeDef :: Definition -> Bool
isTypeDef (SrcPos _ d) = isTypeDef d
isTypeDef (Func _) = False
isTypeDef _ = True
