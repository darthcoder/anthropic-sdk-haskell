module Anthropic.Types
    ( -- * Models
      Model (..)
    , claude3Opus, claude3Sonnet, claude3Haiku
    , claude3_5Sonnet, claude3_5Haiku
    , claudeOpus4, claudeSonnet4, claudeHaiku4
      -- * Primitives
    , Role (..)
    , StopReason (..)
    , Usage (..)
      -- * Response content blocks
    , ContentBlock (..)
      -- * Request content blocks
    , ImageMediaType (..)
    , ImageSource (..)
    , ContentBlockParam (..)
    , MessageContent (..)
      -- * Tools
    , Tool (..)
    , ToolChoice (..)
      -- * Messages
    , MessageParam (..)
    , userMessage
    , assistantMessage
    , MessageRequest (..)
    , Message (..)
      -- * Streaming
    , ContentDelta (..)
    , MessageStreamEvent (..)
    ) where

import Data.Aeson
import Data.Aeson.Types (Parser)
import Data.Maybe       (catMaybes)
import Data.Text        (Text)
import GHC.Generics     (Generic)

import Anthropic.Internal.Json (withPrefix)

-- ---------------------------------------------------------------------------
-- Model

newtype Model = Model { unModel :: Text }
    deriving (Show, Eq, Generic)

instance ToJSON   Model where toJSON   (Model t) = String t
instance FromJSON Model where parseJSON = withText "Model" (pure . Model)

claude3Opus, claude3Sonnet, claude3Haiku :: Model
claude3Opus   = Model "claude-3-opus-20240229"
claude3Sonnet = Model "claude-3-sonnet-20240229"
claude3Haiku  = Model "claude-3-haiku-20240307"

claude3_5Sonnet, claude3_5Haiku :: Model
claude3_5Sonnet = Model "claude-3-5-sonnet-20241022"
claude3_5Haiku  = Model "claude-3-5-haiku-20241022"

claudeOpus4, claudeSonnet4, claudeHaiku4 :: Model
claudeOpus4   = Model "claude-opus-4-5"
claudeSonnet4 = Model "claude-sonnet-4-5"
claudeHaiku4  = Model "claude-haiku-4-5"

-- ---------------------------------------------------------------------------
-- Role

data Role = User | Assistant
    deriving (Show, Eq, Generic)

instance ToJSON Role where
    toJSON User      = "user"
    toJSON Assistant = "assistant"

instance FromJSON Role where
    parseJSON = withText "Role" $ \case
        "user"      -> pure User
        "assistant" -> pure Assistant
        other       -> fail $ "Unknown role: " <> show other

-- ---------------------------------------------------------------------------
-- StopReason

data StopReason = EndTurn | MaxTokens | StopSequence | ToolUse | PauseTurn | Refusal
    deriving (Show, Eq, Generic)

instance FromJSON StopReason where
    parseJSON = withText "StopReason" $ \case
        "end_turn"      -> pure EndTurn
        "max_tokens"    -> pure MaxTokens
        "stop_sequence" -> pure StopSequence
        "tool_use"      -> pure ToolUse
        "pause_turn"    -> pure PauseTurn
        "refusal"       -> pure Refusal
        other           -> fail $ "Unknown stop_reason: " <> show other

-- ---------------------------------------------------------------------------
-- Usage

data Usage = Usage
    { uInputTokens              :: Int
    , uOutputTokens             :: Int
    , uCacheCreationInputTokens :: Maybe Int
    , uCacheReadInputTokens     :: Maybe Int
    } deriving (Show, Eq, Generic)

instance FromJSON Usage where
    parseJSON = genericParseJSON (withPrefix 1)

-- ---------------------------------------------------------------------------
-- ContentBlock (response)
--
-- Discriminated on the "type" field. Unknown variants are silently ignored
-- via the fallthrough — the API may add new types in future.

data ContentBlock
    = TextBlock     { cbText      :: Text }
    | ThinkingBlock { cbThinking  :: Text, cbSignature :: Text }
    | ToolUseBlock  { cbId :: Text, cbName :: Text, cbInput :: Value }
    deriving (Show, Eq)

instance FromJSON ContentBlock where
    parseJSON = withObject "ContentBlock" $ \o -> do
        t <- o .: "type" :: Parser Text
        case t of
            "text"     -> TextBlock <$> o .: "text"
            "thinking" -> ThinkingBlock <$> o .: "thinking" <*> o .: "signature"
            "tool_use" -> ToolUseBlock  <$> o .: "id" <*> o .: "name" <*> o .: "input"
            _          -> fail $ "Unknown content block type: " <> show t

-- ---------------------------------------------------------------------------
-- ImageSource (request)

data ImageMediaType = Jpeg | Png | Gif | Webp
    deriving (Show, Eq)

instance ToJSON ImageMediaType where
    toJSON Jpeg = "image/jpeg"
    toJSON Png  = "image/png"
    toJSON Gif  = "image/gif"
    toJSON Webp = "image/webp"

data ImageSource
    = Base64Image { isMediaType :: ImageMediaType, isData :: Text }
    | UrlImage    { isUrl       :: Text }
    deriving (Show, Eq)

instance ToJSON ImageSource where
    toJSON (Base64Image mt d) = object
        [ "type"       .= ("base64" :: Text)
        , "media_type" .= mt
        , "data"       .= d
        ]
    toJSON (UrlImage u) = object
        [ "type" .= ("url" :: Text)
        , "url"  .= u
        ]

-- ---------------------------------------------------------------------------
-- ContentBlockParam (request)

data ContentBlockParam
    = TextParam       { cpText      :: Text }
    | ImageParam      { cpSource    :: ImageSource }
    | ToolResultParam { cpToolUseId :: Text, cpContent :: [ContentBlockParam] }
    | ToolUseParam    { cpId :: Text, cpName :: Text, cpInput :: Value }
    deriving (Show, Eq)

instance ToJSON ContentBlockParam where
    toJSON (TextParam t) = object
        [ "type" .= ("text" :: Text), "text" .= t ]
    toJSON (ImageParam s) = object
        [ "type" .= ("image" :: Text), "source" .= s ]
    toJSON (ToolResultParam tid content) = object
        [ "type"        .= ("tool_result" :: Text)
        , "tool_use_id" .= tid
        , "content"     .= content
        ]
    toJSON (ToolUseParam tid name inp) = object
        [ "type"  .= ("tool_use" :: Text)
        , "id"    .= tid
        , "name"  .= name
        , "input" .= inp
        ]

-- ---------------------------------------------------------------------------
-- MessageContent
--
-- The API accepts a plain string or an array of content blocks for both
-- the "messages[].content" and "system" fields.

data MessageContent
    = TextContent  Text
    | BlockContent [ContentBlockParam]
    deriving (Show, Eq)

instance ToJSON MessageContent where
    toJSON (TextContent t)   = toJSON t
    toJSON (BlockContent bs) = toJSON bs

-- ---------------------------------------------------------------------------
-- Tool

data Tool = Tool
    { toolName        :: Text
    , toolDescription :: Maybe Text
    , toolInputSchema :: Value   -- JSON Schema object
    } deriving (Show, Eq)

instance ToJSON Tool where
    toJSON t = object $ catMaybes
        [ Just ("name"         .= toolName t)
        , Just ("input_schema" .= toolInputSchema t)
        , ("description" .=) <$> toolDescription t
        ]

-- ---------------------------------------------------------------------------
-- ToolChoice

data ToolChoice
    = ToolChoiceAuto
    | ToolChoiceAny
    | ToolChoiceTool Text   -- ^ Force a specific tool by name
    deriving (Show, Eq)

instance ToJSON ToolChoice where
    toJSON ToolChoiceAuto        = object [ "type" .= ("auto" :: Text) ]
    toJSON ToolChoiceAny         = object [ "type" .= ("any"  :: Text) ]
    toJSON (ToolChoiceTool name) = object [ "type" .= ("tool" :: Text), "name" .= name ]

-- ---------------------------------------------------------------------------
-- MessageParam

data MessageParam = MessageParam
    { mpRole    :: Role
    , mpContent :: MessageContent
    } deriving (Show, Eq)

instance ToJSON MessageParam where
    toJSON (MessageParam r c) = object [ "role" .= r, "content" .= c ]

-- Convenience constructors
userMessage, assistantMessage :: Text -> MessageParam
userMessage      t = MessageParam User      (TextContent t)
assistantMessage t = MessageParam Assistant (TextContent t)

-- ---------------------------------------------------------------------------
-- MessageRequest

data MessageRequest = MessageRequest
    { reqModel         :: Model
    , reqMessages      :: [MessageParam]
    , reqMaxTokens     :: Int
    , reqSystem        :: Maybe MessageContent
    , reqStopSequences :: Maybe [Text]
    , reqTemperature   :: Maybe Double
    , reqTools         :: Maybe [Tool]
    , reqToolChoice    :: Maybe ToolChoice
    } deriving (Show, Eq, Generic)

instance ToJSON MessageRequest where
    toJSON = genericToJSON (withPrefix 3)

-- ---------------------------------------------------------------------------
-- Message (response)

data Message = Message
    { msgId           :: Text
    , msgType         :: Text        -- always "message"
    , msgRole         :: Role
    , msgContent      :: [ContentBlock]
    , msgModel        :: Model
    , msgStopReason   :: Maybe StopReason
    , msgStopSequence :: Maybe Text
    , msgUsage        :: Usage
    } deriving (Show, Eq, Generic)

instance FromJSON Message where
    parseJSON = genericParseJSON (withPrefix 3)

-- ---------------------------------------------------------------------------
-- Streaming event types

-- | Incremental content arriving during a stream.
data ContentDelta
    = TextDelta      Text   -- ^ A chunk of assistant text
    | InputJsonDelta Text   -- ^ A partial JSON string for tool input
    deriving (Show, Eq)

instance FromJSON ContentDelta where
    parseJSON = withObject "ContentDelta" $ \o -> do
        t <- o .: "type" :: Parser Text
        case t of
            "text_delta"       -> TextDelta      <$> o .: "text"
            "input_json_delta" -> InputJsonDelta <$> o .: "partial_json"
            _                  -> fail $ "Unknown delta type: " <> show t

-- | One SSE event emitted by the API during a streaming response.
data MessageStreamEvent
    = EvMessageStart  Message        -- ^ Initial message envelope (content still empty)
    | EvContentDelta  Int ContentDelta -- ^ index, incremental content chunk
    | EvMessageDelta  (Maybe StopReason) -- ^ Final stop reason
    | EvMessageStop                  -- ^ Stream is complete
    | EvPing                         -- ^ Server keep-alive
    deriving (Show, Eq)

instance FromJSON MessageStreamEvent where
    parseJSON = withObject "MessageStreamEvent" $ \o -> do
        t <- o .: "type" :: Parser Text
        case t of
            "message_start"       -> EvMessageStart <$> o .: "message"
            "content_block_delta" -> EvContentDelta <$> o .: "index" <*> o .: "delta"
            "message_delta"       -> do
                delta <- o .: "delta"
                EvMessageDelta <$> delta .:? "stop_reason"
            "message_stop"        -> pure EvMessageStop
            "ping"                -> pure EvPing
            _                     -> pure EvPing   -- ignore unknown event types
