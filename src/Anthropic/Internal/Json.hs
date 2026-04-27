module Anthropic.Internal.Json
    ( aesonOptions
    , withPrefix
    ) where

import Data.Aeson (Options (..), defaultOptions)
import Data.Char  (isUpper, toLower)

-- | Default aeson options: snake_case field names, omit Nothing fields.
aesonOptions :: Options
aesonOptions = defaultOptions
    { fieldLabelModifier = camelToSnake
    , omitNothingFields  = True
    }

-- | Like 'aesonOptions' but strips a n-character prefix first.
-- e.g. @withPrefix 3@ turns @msgStopReason@ → @"stop_reason"@
withPrefix :: Int -> Options
withPrefix n = aesonOptions { fieldLabelModifier = camelToSnake . lowerFirst . drop n }
  where
    lowerFirst []     = []
    lowerFirst (c:cs) = toLower c : cs

camelToSnake :: String -> String
camelToSnake []     = []
camelToSnake (c:cs) = toLower c : go cs
  where
    go []     = []
    go (x:xs)
      | isUpper x = '_' : toLower x : go xs
      | otherwise = x : go xs
