module Wit.Gen.Normalization
  ( normalizeIdentifier,
    externalConvention,
  )
where

externalConvention :: String -> String
externalConvention s = "extern_" ++ normalizeIdentifier s

normalizeIdentifier :: String -> String
normalizeIdentifier = map f
  where
    f '-' = '_'
    f c = c
