module Anthropic.Client
    ( AnthropicConfig (..)
    , AnthropicClient (..)
    , defaultConfig
    , mkClient
    , fromEnv
    ) where

import Data.Text              (Text)
import qualified Data.Text    as T
import Network.HTTP.Client    (Manager)
import Network.HTTP.Client.TLS (newTlsManager)
import System.Environment     (getEnv)

-- ---------------------------------------------------------------------------
-- Config

data AnthropicConfig = AnthropicConfig
    { acApiKey     :: Text
    , acBaseUrl    :: Text
    , acMaxRetries :: Int
    , acTimeoutMs  :: Int
    } deriving (Show)

defaultConfig :: Text -> AnthropicConfig
defaultConfig key = AnthropicConfig
    { acApiKey     = key
    , acBaseUrl    = "https://api.anthropic.com"
    , acMaxRetries = 2
    , acTimeoutMs  = 60_000
    }

-- ---------------------------------------------------------------------------
-- Client

data AnthropicClient = AnthropicClient
    { clientConfig  :: AnthropicConfig
    , clientManager :: Manager          -- shared TLS connection pool
    }

-- | Build a client from a config. Creates a shared TLS Manager.
mkClient :: AnthropicConfig -> IO AnthropicClient
mkClient cfg = AnthropicClient cfg <$> newTlsManager

-- | Read ANTHROPIC_API_KEY from the environment and build a client.
fromEnv :: IO AnthropicClient
fromEnv = T.pack <$> getEnv "ANTHROPIC_API_KEY" >>= mkClient . defaultConfig
