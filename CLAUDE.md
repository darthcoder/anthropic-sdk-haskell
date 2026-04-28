# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Goal

A Haskell SDK for the Anthropic API, targeting feature parity with the [TypeScript SDK](https://github.com/anthropics/anthropic-sdk-typescript). The API base URL is `https://api.anthropic.com`. Auth requires headers `x-api-key`, `anthropic-version: 2023-06-01`, and `content-type: application/json`.

**When implementing features**: The TypeScript SDK is the authoritative reference for API surface, error handling, retry behaviour, and response shapes. Consult the TypeScript source directly when designing new modules or extending existing ones — this project prioritizes correctness over idiomatic Haskell when there's a conflict with the upstream spec.

## Build Commands

```bash
cabal build                              # build library
cabal test                               # run all tests
cabal test --test-show-details=streaming # verbose test output
cabal repl                               # GHCi with library loaded
cabal run examples                       # run live example (needs ANTHROPIC_API_KEY)
cabal run examples -- --stream           # streaming example
cabal run examples -- --mock             # no API key needed; replays fixture
make build / make test / make fixtures   # Makefile shortcuts
hlint src/                               # lint
```

To run a single test suite: `cabal test <test-suite-name>` (defined in `anthropic-sdk-haskell.cabal`).

## GHC Version

**GHC 9.14.1** (`base ^>=4.22.0.0`). This matters because:
- `req` library (3.13.4) requires `template-haskell <2.24`; GHC 9.14 ships 2.24 — **do not add req**.
- `wreq` has the same issue.
- Use plain `http-client` + `http-client-tls` throughout.

## Actual Dependencies

```
http-client, http-client-tls, retry, containers (<0.9), http-types,
aeson, text, bytestring
```

**Not used (despite being in earlier plans):** `conduit`, `http-conduit`, `async`, `transformers`, `mtl`, `req`, `wreq`, `scientific`, `time`, `unliftio-core`.

Default extensions (in cabal): `OverloadedStrings`, `DeriveGeneric`, `LambdaCase`, `ScopedTypeVariables`, `NumericUnderscores`.

## Architecture

Public API modules (all in `src/Anthropic/`):
- **Client.hs** — `AnthropicClient`, `AnthropicConfig`, `mkClient`, `fromEnv`
- **Types.hs** — All request/response types + streaming event types
- **Error.hs** — `AnthropicError` (Exception), `ApiErrorBody`
- **Messages.hs** — `sendMessage :: AnthropicClient -> MessageRequest -> IO Message`
- **Messages/Streaming.hs** — `streamMessage` (callback-based SSE streaming)
- **Messages/Batches.hs** — stub (not yet implemented)
- **Models.hs** — `listModels`, `getModel` (GET /v1/models{/:id})
- **Files.hs** — stub (not yet implemented)
- **TokenCounting.hs** — stub (not yet implemented)
- **Helpers/Tool.hs** — `mkTool` constructor, `decodeToolInput` helper

Internal modules (not part of public API):
- **Internal/Http.hs** — HTTP layer: `postJson`, `getJson`, `mkHeaders`, retry logic
- **Internal/Sse.hs** — SSE parser: `parseChunk` (stateless, carries leftover across chunks)
- **Internal/Json.hs** — JSON helpers: `aesonOptions` (snake_case + omitNothingFields), `withPrefix`

## Key Implementation Patterns

**JSON field naming**: Field names use short prefixes to avoid `DuplicateRecordFields`. The `withPrefix n` helper strips n chars then applies camelToSnake. E.g. `msgStopReason` with `withPrefix 3` → `"stop_reason"`. Prefixes: `msg` (Message), `req` (MessageRequest), `u` (Usage), `mp` (MessageParam), `tool` (Tool), `cp` (ContentBlockParam), `ac` (AnthropicConfig), `ae` (AnthropicError), `mi` (ModelInfo), `ml` (ModelList).

**Retry**: Uses `retrying` (not `recovering`) from the `retry` package — avoids `MonadMask`/`Handler` complexity. Action returns `(Int, ByteString)`; `checkRetry` retries on 408, 409, 429, 5xx (except 501). Backoff: `exponentialBackoff 500_000` capped at 8s, `limitRetries (acMaxRetries cfg)`.

**Streaming**: Callback-based — `streamMessage client req (MessageStreamEvent -> IO ())`. Uses `withResponse` + `brRead` from http-client for true chunk-by-chunk reading. `addStream` injects `"stream": true` via `KM.insert "stream" (Bool True)` on the aeson `Value`. **No conduit.**

**SSE parsing**: Stateless `parseChunk leftover chunk → (newLeftover, [events])`. Splits on `\n\n`, extracts `data: ` lines, decodes JSON. Leftover bytes carried across chunks.

**Error handling**: `AnthropicHttpError` / `AnthropicApiError` / `AnthropicParseError` all implement `Exception`. API error body shape: `{"type":"error","error":{...}}` — `decodeApiError` unwraps via `KM.lookup "error"`.

**Tool use**: Types only. `ContentBlockParam` has `ToolUseParam` and `ToolResultParam` variants. Callers are responsible for the tool execution loop; the SDK just provides the types and `Helpers.Tool` (`mkTool`, `decodeToolInput`) for convenience.

## Testing Pattern

Tests are fixture-based — **zero API calls**, runs in ~2ms. Run with:

```bash
make test                          # all tests with streaming output
cabal test anthropic-sdk-haskell-test  # without Makefile shortcut
```

Fixtures in `test/fixtures/` are generated once via [grievous-mcp](https://pypi.org/project/grievous-mcp/):

```bash
pip install grievous-mcp
export ANTHROPIC_API_KEY=sk-ant-...
make fixtures          # runs test/fixtures/generate.py, regenerates all JSON fixtures
```

Current fixtures: `message_text.json`, `message_tool_use.json`, `message_max_tokens.json`, `error_rate_limit.json`, `error_invalid_request.json`, `error_auth.json`.

Test structure: `test/Test/Types.hs` covers all fixture decode cases + MessageRequest encode + Models API decode. `test/Test/Messages.hs` and `test/Test/Streaming.hs` are stubs.

## Feature Parity Checklist

- [x] `Messages` — blocking POST /v1/messages
- [x] `Messages.Streaming` — SSE callback stream
- [x] Tool use types (`ToolUseBlock`, `ToolResultParam`, `Tool`, `ToolChoice`)
- [x] Auto-retry with exponential backoff
- [x] Configurable timeouts
- [x] `ANTHROPIC_API_KEY` env-var via `fromEnv`
- [ ] `Messages.Batches` — POST /v1/messages/batches (submit + poll)
- [x] `TokenCounting` — POST /v1/messages/count_tokens (`countTokens`)
- [x] `Models` — GET /v1/models (`listModels`, `getModel`)
- [ ] `Files` — POST/GET /v1/files
- [ ] Streaming test suite (SSE fixture via grievous-mcp)
- [ ] Live integration test (guarded by env var)
