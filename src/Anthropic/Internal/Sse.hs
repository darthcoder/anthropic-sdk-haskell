module Anthropic.Internal.Sse
    ( parseChunk
    ) where

import Data.Aeson                  (FromJSON, eitherDecode)
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy  as LB
import Data.Maybe                  (mapMaybe)

-- | Feed a raw byte chunk into the SSE parser.
--
-- Returns (leftover bytes not yet forming a complete event, decoded events).
-- Callers should prepend the leftover to the next chunk.
--
-- SSE wire format:
--   event: <name>\n
--   data: <json>\n
--   \n
--
-- We only care about the @data:@ line; the @event:@ name is redundant with
-- the @"type"@ field inside the JSON payload.
parseChunk :: FromJSON a => BC.ByteString -> BC.ByteString -> (BC.ByteString, [a])
parseChunk leftover chunk =
    let buf    = normalize (leftover <> chunk)
        blocks = splitOnBlankLine buf
        allComplete = "\n\n" `BC.isSuffixOf` buf
    in if allComplete
        then (BC.empty, mapMaybe decodeBlock blocks)
        else case reverse blocks of
            []           -> (BC.empty, [])
            (inc : rest) -> (inc, mapMaybe decodeBlock (reverse rest))

-- ---------------------------------------------------------------------------
-- Helpers

-- | Strip CR so the rest of the parser only sees @\n@ line endings.
normalize :: BC.ByteString -> BC.ByteString
normalize = BC.filter (/= '\r')

-- | Split on @\n\n@, keeping the separator consumed.
splitOnBlankLine :: BC.ByteString -> [BC.ByteString]
splitOnBlankLine bs
    | BC.null bs = []
    | otherwise  =
        let (block, rest) = BC.breakSubstring "\n\n" bs
        in  if BC.null rest
                then [block]
                else block : splitOnBlankLine (BC.drop 2 rest)

-- | Extract the @data: @ payload from one SSE event block and decode it.
decodeBlock :: FromJSON a => BC.ByteString -> Maybe a
decodeBlock block =
    let ls    = BC.lines block
        datas = [ BC.drop 6 l | l <- ls, "data: " `BC.isPrefixOf` l ]
    in case datas of
        []    -> Nothing
        (d:_) -> case eitherDecode (LB.fromStrict d) of
            Right v -> Just v
            Left _  -> Nothing
