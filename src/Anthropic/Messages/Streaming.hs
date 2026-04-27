module Anthropic.Messages.Streaming
    ( streamMessage
    ) where

import Control.Exception           (throwIO)
import Data.Aeson                  (Value (..), encode, toJSON)
import qualified Data.Aeson.KeyMap     as KM
import qualified Data.ByteString.Char8 as BC
import qualified Data.Text             as T
import Network.HTTP.Client
import Network.HTTP.Types          (statusCode)

import Anthropic.Client           (AnthropicClient (..), AnthropicConfig (..))
import Anthropic.Error            (AnthropicError (..))
import Anthropic.Internal.Http    (mkHeaders)
import Anthropic.Internal.Sse     (parseChunk)
import Anthropic.Types

-- | Stream a message from the Anthropic API, calling @onEvent@ for each
-- SSE event as it arrives. Blocks until the stream is complete.
--
-- Example:
--
-- > streamMessage client req $ \ev -> case ev of
-- >     EvContentDelta _ (TextDelta t) -> putStr (T.unpack t)
-- >     EvMessageStop                  -> putStrLn ""
-- >     _                              -> pure ()
streamMessage
    :: AnthropicClient
    -> MessageRequest
    -> (MessageStreamEvent -> IO ())   -- ^ called once per SSE event
    -> IO ()
streamMessage client req onEvent = do
    let cfg = clientConfig client
        mgr = clientManager client
    baseReq <- parseUrlThrow (T.unpack (acBaseUrl cfg) <> "/v1/messages")
    let httpReq = baseReq
            { method         = "POST"
            , requestBody    = RequestBodyLBS (encode (addStream (toJSON req)))
            , requestHeaders = mkHeaders cfg
            , responseTimeout = responseTimeoutMicro (acTimeoutMs cfg * 1_000)
            }
    withResponse httpReq mgr $ \resp -> do
        let status = statusCode (responseStatus resp)
        if status < 200 || status >= 300
            then throwIO (AnthropicHttpError status mempty)
            else drainEvents (responseBody resp) BC.empty onEvent

-- ---------------------------------------------------------------------------
-- Helpers

-- | Inject @"stream": true@ into the JSON object for the request body.
addStream :: Value -> Value
addStream (Object o) = Object (KM.insert "stream" (Bool True) o)
addStream v          = v

-- | Read chunks from the response body, parse SSE events, call the handler.
drainEvents
    :: BodyReader
    -> BC.ByteString                   -- leftover from previous chunk
    -> (MessageStreamEvent -> IO ())
    -> IO ()
drainEvents br leftover onEvent = do
    chunk <- brRead br
    if BC.null chunk
        then do
            let (_, events) = parseChunk leftover "\n\n"
            mapM_ onEvent events
        else do
            let (leftover', events) = parseChunk leftover chunk
            mapM_ onEvent events
            drainEvents br leftover' onEvent
