# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

A Haskell SDK for the Anthropic API, targeting feature parity with the [TypeScript SDK](https://github.com/anthropics/anthropic-sdk-typescript). The API base URL is `https://api.anthropic.com`. Auth requires headers `x-api-key`, `anthropic-version: 2023-06-01`, and `content-type: application/json`.

## Build Commands

```bash
cabal build                              # build library
cabal test                               # run all tests
cabal test --test-show-details=streaming # verbose test output
cabal repl                               # GHCi with library loaded
cabal run <executable>                   # run an example
hlint src/                               # lint
```

To run a single test suite: `cabal test <test-suite-name>` (defined in `anthropic-sdk-haskell.cabal`).

## Planned API Surface

The following endpoints must be covered, matching the TypeScript SDK's module structure:

| Module | Endpoint | Notes |
|---|---|---|
| `Messages` | `POST /v1/messages` | Core chat; supports SSE streaming |
| `Messages.Streaming` | `POST /v1/messages` (stream=true) | SSE event loop |
| `Messages.Batches` | `POST /v1/messages/batches` | Async batch (50% cost reduction) |
| `TokenCounting` | `POST /v1/messages/count_tokens` | Pre-estimate token usage |
| `Models` | `GET /v1/models` | List available Claude models |
| `Files` | `POST /v1/files`, `GET /v1/files` | Upload/retrieve files |

## Dependency Choices

| Concern | Package |
|---|---|
| HTTP client | `http-client` + `http-client-tls` |
| Streaming (SSE) | `http-conduit` + `conduit` |
| JSON | `aeson` with `DeriveGeneric` |
| Async/concurrency | `async` |
| Retry logic | `retry` |

## Architecture

```
src/
  Anthropic/
    Client.hs          -- AnthropicClient config (API key, base URL, timeouts, manager)
    Types.hs           -- Shared request/response types (Message, Content, Role, Model…)
    Error.hs           -- Typed API errors (AnthropicError, ErrorCode variants)
    Messages.hs        -- POST /v1/messages (non-streaming)
    Messages/
      Streaming.hs     -- SSE streaming via Conduit; exposes a Source of events
      Batches.hs       -- Batch submit + poll
    Models.hs          -- GET /v1/models
    Files.hs           -- File upload / retrieval
    TokenCounting.hs   -- Token count helper
    Internal/
      Http.hs          -- Low-level http-client helpers, retry, header injection
      Sse.hs           -- SSE line parser (Conduit transformer)
```

`AnthropicClient` carries a shared `Manager` (from `http-client`) and is the value passed to every API call. Construct with `mkClient :: AnthropicConfig -> IO AnthropicClient`.

## Key Implementation Patterns

**Retry**: Wrap every HTTP call in `recovering` from the `retry` package — exponential backoff for HTTP 429 / 5xx (except 501).

**Streaming**: `POST /v1/messages` with `"stream": true` returns an SSE body. Parse with a Conduit pipeline: `responseBodySource .| sseParser .| messageEventSink`. Expose as `streamMessage :: AnthropicClient -> MessageRequest -> ConduitT () MessageStreamEvent IO ()`.

**Tool use**: `Content` includes a `ToolUse` variant. The caller is responsible for executing tools and sending `tool_result` back; the SDK provides the types, not an agentic loop.

**Errors**: Decode error bodies into `AnthropicError { type_, error :: ApiError }`. Throw as Haskell exceptions (via `throwIO`) so callers can use `catch`/`try`.

**JSON**: Use `snake_case` field names matching the API. Configure aeson with `aesonOptions = defaultOptions { fieldLabelModifier = camelToSnake }` in `Internal/Json.hs`.

## Feature Parity Checklist

- [ ] `Messages` — basic request/response
- [ ] `Messages.Streaming` — SSE event source
- [ ] `Messages.ToolUse` — types for tool definitions and tool_result
- [ ] `Messages.Batches` — submit, retrieve, list, cancel
- [ ] `TokenCounting` — count_tokens endpoint
- [ ] `Models` — list models
- [ ] `Files` — upload, list, get, delete
- [ ] Auto-retry with exponential backoff
- [ ] Configurable timeouts
- [ ] `ANTHROPIC_API_KEY` env-var fallback in `mkClient`
