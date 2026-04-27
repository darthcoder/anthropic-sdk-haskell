module Anthropic.Error
    ( ErrorType (..)
    , ApiErrorBody (..)
    , AnthropicError (..)
    ) where

import Control.Exception  (Exception)
import Data.Aeson
import Data.ByteString.Lazy (ByteString)
import Data.Text          (Text)
import GHC.Generics       (Generic)

import Anthropic.Internal.Json (withPrefix)

-- ---------------------------------------------------------------------------
-- ErrorType
--
-- Maps the "type" string in the API error body. Unknown types fall through
-- to ApiError rather than failing the parse.

data ErrorType
    = InvalidRequestError
    | AuthenticationError
    | PermissionError
    | NotFoundError
    | RateLimitError
    | OverloadedError
    | BillingError
    | ApiError          -- ^ catch-all for unrecognised error types
    deriving (Show, Eq, Generic)

instance FromJSON ErrorType where
    parseJSON = withText "ErrorType" $ \case
        "invalid_request_error" -> pure InvalidRequestError
        "authentication_error"  -> pure AuthenticationError
        "permission_error"      -> pure PermissionError
        "not_found_error"       -> pure NotFoundError
        "rate_limit_error"      -> pure RateLimitError
        "overloaded_error"      -> pure OverloadedError
        "billing_error"         -> pure BillingError
        _                       -> pure ApiError

-- ---------------------------------------------------------------------------
-- ApiErrorBody
--
-- The inner object inside {"type":"error","error":{...}}.
-- Fields: aebType → "type", aebMessage → "message"

data ApiErrorBody = ApiErrorBody
    { aebType    :: ErrorType
    , aebMessage :: Text
    } deriving (Show, Eq, Generic)

instance FromJSON ApiErrorBody where
    parseJSON = genericParseJSON (withPrefix 3)

-- ---------------------------------------------------------------------------
-- AnthropicError
--
-- The exception type thrown by all SDK functions. Callers use
-- Control.Exception.catch / try to handle it.

data AnthropicError
    = AnthropicApiError
        { aeStatus :: Int
        , aeBody   :: ApiErrorBody
        }
    | AnthropicHttpError
        { aeStatus  :: Int
        , aeRawBody :: ByteString
        }
    | AnthropicParseError
        { aeRawBody    :: ByteString
        , aeParseError :: String
        }
    deriving (Show)

instance Exception AnthropicError
