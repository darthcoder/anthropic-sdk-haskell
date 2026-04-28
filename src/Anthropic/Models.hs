module Anthropic.Models
    ( listModels
    , getModel
      -- * Re-exports
    , ModelInfo (..)
    , ModelList (..)
    ) where

import Data.Text                   (Text)
import qualified Data.Text         as T

import Anthropic.Client            (AnthropicClient)
import Anthropic.Internal.Http     (getJson)
import Anthropic.Types             (ModelInfo (..), ModelList (..))

-- | Retrieve the list of available models (GET /v1/models).
listModels :: AnthropicClient -> IO ModelList
listModels client = getJson client "/v1/models"

-- | Retrieve a specific model by ID (GET /v1/models/:model_id).
getModel :: AnthropicClient -> Text -> IO ModelInfo
getModel client modelId = getJson client ("/v1/models/" <> T.unpack modelId)
