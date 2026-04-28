module Test.Types (spec) where

import Data.Aeson             (FromJSON, Value (..), decode, encode, eitherDecode)
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Lazy as LB
import Test.Hspec

import Anthropic.Error (ApiErrorBody (..), ErrorType (..))
import Anthropic.Types

-- ---------------------------------------------------------------------------
-- Helpers

fixtureDir :: FilePath
fixtureDir = "test/fixtures"

loadFixture :: FilePath -> IO LB.ByteString
loadFixture name = LB.readFile (fixtureDir <> "/" <> name <> ".json")

decodeOrFail :: (Show a, Eq a, FromJSON a) => LB.ByteString -> IO a
decodeOrFail bs = case eitherDecode bs of
    Right v  -> pure v
    Left err -> fail $ "JSON decode failed: " <> err

-- | Extract the inner "error" object from the API error envelope.
extractErrorBody :: LB.ByteString -> IO ApiErrorBody
extractErrorBody bs = case decode bs of
    Just (Object obj) | Just v <- KM.lookup "error" obj ->
        case eitherDecode (encode v) of
            Right e  -> pure e
            Left err -> fail $ "Could not decode error body: " <> err
    _ -> fail "Could not find 'error' key in fixture"

-- ---------------------------------------------------------------------------
-- Spec

spec :: Spec
spec = do

    describe "Message decoding" $ do

        it "decodes a simple text response" $ do
            bs  <- loadFixture "message_text"
            msg <- decodeOrFail bs :: IO Message
            msgId   msg `shouldBe` "msg_01AbCdEfGhIjKlMnOpQrStUv"
            msgRole msg `shouldBe` Assistant
            msgModel msg `shouldBe` claude3_5Sonnet
            msgStopReason msg `shouldBe` Just EndTurn
            msgContent msg `shouldBe` [TextBlock "Hello! How can I help you today?"]

        it "decodes a tool_use response" $ do
            bs  <- loadFixture "message_tool_use"
            msg <- decodeOrFail bs :: IO Message
            msgStopReason msg `shouldBe` Just ToolUse
            case msgContent msg of
                [ToolUseBlock tid name _] -> do
                    tid  `shouldBe` "toolu_01AbCdEfGh"
                    name `shouldBe` "get_weather"
                other -> expectationFailure $
                    "Expected [ToolUseBlock], got: " <> show other

        it "decodes a max_tokens response" $ do
            bs  <- loadFixture "message_max_tokens"
            msg <- decodeOrFail bs :: IO Message
            msgStopReason msg `shouldBe` Just MaxTokens

    describe "Usage decoding" $ do

        it "parses token counts from a text response" $ do
            bs  <- loadFixture "message_text"
            msg <- decodeOrFail bs :: IO Message
            let u = msgUsage msg
            uInputTokens  u `shouldBe` 25
            uOutputTokens u `shouldBe` 13

        it "treats null cache fields as Nothing" $ do
            bs  <- loadFixture "message_text"
            msg <- decodeOrFail bs :: IO Message
            uCacheCreationInputTokens (msgUsage msg) `shouldBe` Nothing
            uCacheReadInputTokens     (msgUsage msg) `shouldBe` Nothing

    describe "Error decoding" $ do

        it "decodes a rate_limit_error" $ do
            bs  <- loadFixture "error_rate_limit"
            err <- extractErrorBody bs
            aebType err `shouldBe` RateLimitError

        it "decodes an invalid_request_error" $ do
            bs  <- loadFixture "error_invalid_request"
            err <- extractErrorBody bs
            aebType    err `shouldBe` InvalidRequestError
            aebMessage err `shouldBe` "max_tokens must be a positive integer"

        it "decodes an authentication_error" $ do
            bs  <- loadFixture "error_auth"
            err <- extractErrorBody bs
            aebType err `shouldBe` AuthenticationError

    describe "MessageRequest encoding" $ do

        let req = MessageRequest
                { reqModel         = claude3_5Sonnet
                , reqMessages      = [userMessage "Hello"]
                , reqMaxTokens     = 1024
                , reqSystem        = Nothing
                , reqStopSequences = Nothing
                , reqTemperature   = Nothing
                , reqTools         = Nothing
                , reqToolChoice    = Nothing
                }

        it "encodes to snake_case keys" $ do
            case encode req of
                bs | Just (Object o) <- decode bs -> do
                    KM.member "max_tokens" o `shouldBe` True
                    KM.member "model"      o `shouldBe` True
                    KM.member "messages"   o `shouldBe` True
                _ -> expectationFailure "Expected a JSON object"

        it "omits Nothing fields" $ do
            case encode req of
                bs | Just (Object o) <- decode bs -> do
                    KM.member "system"         o `shouldBe` False
                    KM.member "stop_sequences" o `shouldBe` False
                    KM.member "temperature"    o `shouldBe` False
                _ -> expectationFailure "Expected a JSON object"

        it "encodes the model as a plain string" $ do
            case encode req of
                bs | Just (Object o) <- decode bs
                   , Just (String m) <- KM.lookup "model" o ->
                       m `shouldBe` "claude-3-5-sonnet-20241022"
                _ -> expectationFailure "Expected model to be a string"

    describe "Models API decoding" $ do

        it "decodes a model list response" $ do
            bs  <- loadFixture "models_list"
            ml  <- decodeOrFail bs :: IO ModelList
            length (mlData ml) `shouldBe` 3
            mlHasMore ml       `shouldBe` False
            mlFirstId ml       `shouldBe` Just "claude-opus-4-5"
            mlLastId  ml       `shouldBe` Just "claude-haiku-4-5"

        it "decodes ModelInfo fields correctly" $ do
            bs  <- loadFixture "models_list"
            ml  <- decodeOrFail bs :: IO ModelList
            let mi = case mlData ml of { m:_ -> m; [] -> error "empty" }
            miId          mi `shouldBe` "claude-opus-4-5"
            miDisplayName mi `shouldBe` "Claude Opus 4.5"
            miType        mi `shouldBe` "model"

        it "decodes a single model response" $ do
            bs <- loadFixture "model_get"
            mi <- decodeOrFail bs :: IO ModelInfo
            miId          mi `shouldBe` "claude-sonnet-4-5"
            miDisplayName mi `shouldBe` "Claude Sonnet 4.5"
            miCreatedAt   mi `shouldBe` "2025-02-19T00:00:00Z"

    describe "TokenCounting API" $ do

        it "decodes a token count response" $ do
            bs  <- loadFixture "token_count"
            tc  <- decodeOrFail bs :: IO TokenCount
            tcInputTokens tc `shouldBe` 42

        it "encodes a token count request" $ do
            let req = TokenCountRequest
                    { tcrModel    = claude3_5Sonnet
                    , tcrMessages = [userMessage "Hello"]
                    , tcrSystem   = Nothing
                    }
            case encode req of
                bs | Just (Object o) <- decode bs -> do
                    KM.member "model"    o `shouldBe` True
                    KM.member "messages" o `shouldBe` True
                    KM.member "system"   o `shouldBe` False
                _ -> expectationFailure "Expected a JSON object"
