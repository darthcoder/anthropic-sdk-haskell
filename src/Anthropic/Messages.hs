module Anthropic.Messages
    ( sendMessage
      -- * Re-exports for convenience
    , module Anthropic.Types
    ) where

import Anthropic.Client       (AnthropicClient)
import Anthropic.Internal.Http (postJson)
import Anthropic.Types

-- | Send a message to the Anthropic API and wait for the full response.
--
-- Throws 'Anthropic.Error.AnthropicError' on API errors, parse failures,
-- or after exhausting retries on transient failures.
--
-- Example:
--
-- > client <- fromEnv
-- > let req = MessageRequest
-- >         { reqModel      = claude3_5Sonnet
-- >         , reqMessages   = [userMessage "Hello!"]
-- >         , reqMaxTokens  = 1024
-- >         , reqSystem     = Nothing
-- >         , reqStopSequences = Nothing
-- >         , reqTemperature   = Nothing
-- >         , reqTools         = Nothing
-- >         , reqToolChoice    = Nothing
-- >         }
-- > msg <- sendMessage client req
-- > print (msgContent msg)
sendMessage :: AnthropicClient -> MessageRequest -> IO Message
sendMessage client = postJson client "/v1/messages"

