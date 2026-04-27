# anthropic-sdk-haskell

> **This is an unofficial, community learning project. It is not affiliated with, endorsed by, or supported by Anthropic.**

A Haskell client for the [Anthropic API](https://docs.anthropic.com/), written to explore idiomatic Haskell patterns for HTTP clients, streaming, and type-safe API design. The target feature set mirrors the [official TypeScript SDK](https://github.com/anthropics/anthropic-sdk-typescript).

## Status

Early development. Core Messages API and SSE streaming are implemented and tested.

| Feature | Status |
|---|---|
| Messages (sync) | ✅ Done |
| Streaming (SSE) | ✅ Done |
| Tool use types | ✅ Done (types only; agentic loop is caller responsibility) |
| Batches | Planned |
| Token counting | Planned |
| Models | Planned |
| Files | Planned |

## Design Approach

The TypeScript SDK is used as the authoritative reference for API surface and behaviour (retry logic, error shapes, streaming semantics). Where the TypeScript SDK vendored third-party utilities (e.g. `partial-json-parser` for incomplete JSON chunks during streaming), we use idiomatic Haskell equivalents instead — in this case `aeson` with `attoparsec`'s incremental input, which handles partial parses natively without a custom parser.

The SDK is structured around a single `AnthropicClient` value that carries the HTTP manager, API key, and configuration. Every API function takes this as its first argument.

```
src/Anthropic/
  Client.hs              -- AnthropicClient, mkClient, config
  Types.hs               -- Shared request/response types
  Error.hs               -- Typed API errors
  Messages.hs            -- POST /v1/messages
  Messages/Streaming.hs  -- SSE streaming (callback-based, no conduit)
  Messages/Batches.hs    -- Async batch processing
  Models.hs              -- GET /v1/models
  Files.hs               -- File upload / retrieval
  TokenCounting.hs       -- POST /v1/messages/count_tokens
  Internal/              -- HTTP helpers, SSE parser, JSON options
```

## Installation

Not yet published to Hackage. To use from source:

```bash
git clone https://github.com/darthcoder/anthropic-sdk-haskell
cd anthropic-sdk-haskell
cabal build
```

Add to your own project's `cabal.project`:

```
packages: .
          /path/to/anthropic-sdk-haskell
```

Or use `source-repository-package`:

```
source-repository-package
    type:     git
    location: https://github.com/darthcoder/anthropic-sdk-haskell
    tag:      <commit-sha>
```

## Quick Start

### Blocking request

```haskell
import Anthropic.Client
import Anthropic.Messages
import Anthropic.Types

main :: IO ()
main = do
    client <- fromEnv  -- reads ANTHROPIC_API_KEY from environment
    let req = MessageRequest
            { reqModel         = claude3_5Sonnet
            , reqMessages      = [userMessage "Hello, Claude!"]
            , reqMaxTokens     = 1024
            , reqSystem        = Nothing
            , reqStopSequences = Nothing
            , reqTemperature   = Nothing
            , reqTools         = Nothing
            , reqToolChoice    = Nothing
            }
    msg <- sendMessage client req
    mapM_ print (msgContent msg)
```

### Streaming

```haskell
import Anthropic.Messages.Streaming (streamMessage)
import qualified Data.Text.IO as TIO

main :: IO ()
main = do
    client <- fromEnv
    streamMessage client req $ \ev -> case ev of
        EvContentDelta _ (TextDelta t) -> TIO.putStr t
        EvMessageStop                  -> putStrLn ""
        _                              -> pure ()
```

### Running the example app

```bash
cabal run examples              # live API (needs ANTHROPIC_API_KEY)
cabal run examples -- --stream  # live streaming, prints tokens as they arrive
cabal run examples -- --mock    # replay test/fixtures/message_text.json (no key needed)
```

## Testing

Tests are fixture-based — no API calls, no rate limits, runs in milliseconds.

```bash
make test
```

Fixtures in `test/fixtures/` are generated using [grievous-mcp](https://pypi.org/project/grievous-mcp/), a hallucination engine that produces realistic Anthropic API response shapes via the API. To regenerate them:

```bash
pip install grievous-mcp
export ANTHROPIC_API_KEY=sk-ant-...
make fixtures
```

## Dependency Notes

| Concern | Library |
|---|---|
| HTTP | `http-client` + `http-client-tls` |
| JSON | `aeson` |
| Retry | `retry` (exponential backoff) |

## Contributing

Issues and PRs welcome. This is a learning project — prefer clarity and idiomatic Haskell over micro-optimisations.

## Licence

MIT
