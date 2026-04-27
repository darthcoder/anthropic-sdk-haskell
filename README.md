# anthropic-sdk-haskell

> **This is an unofficial, community learning project. It is not affiliated with, endorsed by, or supported by Anthropic.**

A Haskell client for the [Anthropic API](https://docs.anthropic.com/), written to explore idiomatic Haskell patterns for HTTP clients, streaming, and type-safe API design. The target feature set mirrors the [official TypeScript SDK](https://github.com/anthropics/anthropic-sdk-typescript).

## Status

Early development. The module structure is in place; implementations are being filled in.

| Feature | Status |
|---|---|
| Messages | In progress |
| Streaming (SSE) | In progress |
| Tool use | Planned |
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
  Messages/Streaming.hs  -- SSE streaming via Conduit
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

```haskell
import Anthropic.Client
import Anthropic.Messages
import Anthropic.Types

main :: IO ()
main = do
    client <- mkClient defaultConfig  -- reads ANTHROPIC_API_KEY from env
    response <- sendMessage client MessageRequest
        { model    = Claude3_5Sonnet
        , messages = [userMessage "Hello, Claude!"]
        , maxTokens = 1024
        }
    print response
```

## Dependency Notes

| Concern | Library |
|---|---|
| HTTP | `http-client` + `http-client-tls` |
| Streaming (SSE) | `http-conduit` + `conduit` |
| JSON | `aeson` (incremental via `attoparsec`) |
| Retry | `retry` (exponential backoff) |
| Async | `async` |

## Contributing

Issues and PRs welcome. This is a learning project — prefer clarity and idiomatic Haskell over micro-optimisations.

## Licence

MIT
