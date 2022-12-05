module Wit.Gen.Normalization
  ( normalizeIdentifier,
  )
where

normalizeIdentifier :: String -> String
normalizeIdentifier = map f
  where
    f '-' = '_'
    f c = c