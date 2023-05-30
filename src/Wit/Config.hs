module Wit.Config
  ( Config (..),
    Direction (..),
    Mode (..),
    SupportedLanguage (..),
  )
where

data SupportedLanguage
  = Rust

data Direction
  = Import
  | Export

type PluginName = String

data Mode
  = Instance Direction
  | Runtime Direction
  | Plugin PluginName

data Config = Config
  { language :: SupportedLanguage,
    codegenMode :: Mode
  }
