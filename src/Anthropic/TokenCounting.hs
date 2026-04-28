module Anthropic.TokenCounting
    ( countTokens
      -- * Re-exports
    , TokenCountRequest (..)
    , TokenCount (..)
    ) where

import Anthropic.Client            (AnthropicClient)
import Anthropic.Internal.Http     (postJson)
import Anthropic.Types             (TokenCountRequest (..), TokenCount (..))

-- | Count the number of tokens in a given message request (POST /v1/messages/count_tokens).
--
-- This endpoint counts the number of tokens that would be consumed by a message request,
-- without actually executing it. Useful for checking if a request would exceed the model's
-- token limit before sending it.
--
-- Throws 'Anthropic.Error.AnthropicError' on API errors or parse failures.
--
-- Example:
--
-- > client <- fromEnv
-- > let req = TokenCountRequest
-- >         { tcrModel    = claude3_5Sonnet
-- >         , tcrMessages = [userMessage "Hello, Claude!"]
-- >         , tcrSystem   = Nothing
-- >         }
-- > result <- countTokens client req
-- > print (tcInputTokens result)
countTokens :: AnthropicClient -> TokenCountRequest -> IO TokenCount
countTokens client = postJson client "/v1/messages/count_tokens"
