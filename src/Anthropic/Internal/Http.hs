module Anthropic.Internal.Http
    ( postJson
    , getJson
    , mkHeaders
    ) where

import Control.Exception          (throwIO)
import Control.Retry              (RetryStatus, RetryPolicyM, retrying,
                                   exponentialBackoff, limitRetries, capDelay)
import Data.Aeson                 (FromJSON, ToJSON, Value (..),
                                   decode, eitherDecode, encode, fromJSON, Result (..))
import qualified Data.Aeson.KeyMap    as KM
import qualified Data.ByteString.Lazy as LB
import qualified Data.Text            as T
import Data.Text.Encoding          (encodeUtf8)
import Network.HTTP.Client
import Network.HTTP.Types          (RequestHeaders, statusCode)

import Anthropic.Client (AnthropicClient (..), AnthropicConfig (..))
import Anthropic.Error  (AnthropicError (..), ApiErrorBody)

-- ---------------------------------------------------------------------------
-- Public

postJson
    :: (ToJSON req, FromJSON resp)
    => AnthropicClient
    -> String           -- ^ path, e.g. "/v1/messages"
    -> req
    -> IO resp
postJson client apiPath body = do
    let cfg = clientConfig client
        mgr = clientManager client
    baseReq <- parseUrlThrow (T.unpack (acBaseUrl cfg) <> apiPath)
    let req = baseReq
            { method         = "POST"
            , requestBody    = RequestBodyLBS (encode body)
            , requestHeaders = mkHeaders cfg
            , responseTimeout = responseTimeoutMicro (acTimeoutMs cfg * 1_000)
            }
    (status, rb) <- retrying (retryPolicy cfg) checkRetry $ \_ -> do
        resp <- httpLbs req mgr
        pure (statusCode (responseStatus resp), responseBody resp)
    if status >= 200 && status < 300
        then case eitherDecode rb of
                 Right v  -> pure v
                 Left err -> throwIO (AnthropicParseError rb err)
        else case decodeApiError rb of
                 Just e  -> throwIO (AnthropicApiError status e)
                 Nothing -> throwIO (AnthropicHttpError status rb)

getJson
    :: FromJSON resp
    => AnthropicClient
    -> String           -- ^ path, e.g. "/v1/models"
    -> IO resp
getJson client apiPath = do
    let cfg = clientConfig client
        mgr = clientManager client
    baseReq <- parseUrlThrow (T.unpack (acBaseUrl cfg) <> apiPath)
    let req = baseReq
            { method          = "GET"
            , requestHeaders  = mkHeaders cfg
            , responseTimeout = responseTimeoutMicro (acTimeoutMs cfg * 1_000)
            }
    (status, rb) <- retrying (retryPolicy cfg) checkRetry $ \_ -> do
        resp <- httpLbs req mgr
        pure (statusCode (responseStatus resp), responseBody resp)
    if status >= 200 && status < 300
        then case eitherDecode rb of
                 Right v  -> pure v
                 Left err -> throwIO (AnthropicParseError rb err)
        else case decodeApiError rb of
                 Just e  -> throwIO (AnthropicApiError status e)
                 Nothing -> throwIO (AnthropicHttpError status rb)

-- ---------------------------------------------------------------------------
-- Helpers

mkHeaders :: AnthropicConfig -> RequestHeaders
mkHeaders cfg =
    [ ("x-api-key",         encodeUtf8 (acApiKey cfg))
    , ("anthropic-version", "2023-06-01")
    , ("content-type",      "application/json")
    , ("user-agent",        "anthropic-sdk-haskell/0.1.0.0")
    ]

-- | 500ms → 1s → 2s → … capped at 8s, limited to acMaxRetries attempts.
retryPolicy :: AnthropicConfig -> RetryPolicyM IO
retryPolicy cfg = capDelay 8_000_000 (exponentialBackoff 500_000)
               <> limitRetries (acMaxRetries cfg)

-- | Retry on rate-limit, timeout, and transient server errors.
checkRetry :: RetryStatus -> (Int, LB.ByteString) -> IO Bool
checkRetry _ (s, _) = pure $ s `elem` [408, 409, 429] || (s >= 500 && s /= 501)

-- | Unwrap {"type":"error","error":{...}} and decode the inner object.
decodeApiError :: LB.ByteString -> Maybe ApiErrorBody
decodeApiError rb = do
    Object obj <- decode rb
    errVal     <- KM.lookup "error" obj
    case fromJSON errVal of
        Success e -> Just e
        Error _   -> Nothing
