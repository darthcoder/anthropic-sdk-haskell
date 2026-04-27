module Anthropic.Helpers.Tool
    ( mkTool
    , decodeToolInput
    ) where

import Data.Aeson        (FromJSON, Value, fromJSON, Result (..))
import Data.Text         (Text)

import Anthropic.Types   (Tool (..), ContentBlock (..))

-- | Convenience constructor for 'Tool'. Equivalent to filling the record.
mkTool :: Text -> Text -> Value -> Tool
mkTool name desc schema = Tool
    { toolName        = name
    , toolDescription = Just desc
    , toolInputSchema = schema
    }

-- | Decode the input arguments of a 'ToolUseBlock' into a typed value.
-- Returns 'Left' with an error message if the block is not a 'ToolUseBlock'
-- or if the JSON does not match the expected type.
decodeToolInput :: FromJSON a => ContentBlock -> Either String a
decodeToolInput (ToolUseBlock _ _ inp) = case fromJSON inp of
    Success a -> Right a
    Error e   -> Left e
decodeToolInput other =
    Left $ "expected ToolUseBlock, got: " <> show other
