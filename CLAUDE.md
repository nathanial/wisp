# CLAUDE.md

HTTP client library for Lean 4, built on libcurl.

## Build & Test

```bash
lake build
lake test
```

## Requirements

libcurl development libraries required:
- **macOS**: `brew install curl` (Homebrew curl 8.11+ for WebSocket support)
- **Ubuntu/Debian**: `apt-get install libcurl4-openssl-dev`
- **Fedora/RHEL**: `dnf install libcurl-devel`

## Architecture

```
Wisp/
├── Core/
│   ├── Types.lean      # Method, Headers, URL types
│   ├── Error.lean      # WispError, WispResult
│   ├── Request.lean    # Request builder (fluent API)
│   ├── Response.lean   # Response type and status helpers
│   ├── Streaming.lean  # StreamingResponse for large responses
│   └── WebSocket.lean  # WebSocket client support
├── FFI/
│   ├── Easy.lean       # curl_easy_* bindings
│   └── Multi.lean      # curl_multi_* bindings (async)
└── HTTP/
    ├── Client.lean     # High-level HTTP client
    ├── SSE.lean        # Server-Sent Events parser
    └── WebSocket.lean  # WebSocket high-level API
```

Native C code in `native/src/wisp_ffi.c`.

## Key Patterns

### Request Builder (Fluent API)
```lean
let req := Wisp.Request.post url
  |>.withJson """{"key": "value"}"""
  |>.withBearerToken token
  |>.withTimeout 5000
```

### Client Usage
```lean
Wisp.FFI.globalInit  -- Call once at startup
let client := Wisp.HTTP.Client.new
let task ← client.get "https://example.com"
let result := task.get
-- ...
Wisp.FFI.globalCleanup
Wisp.HTTP.Client.shutdown
```

### Streaming & SSE
```lean
let task ← client.executeStreaming req
let sse ← Wisp.HTTP.SSE.Stream.fromStreaming streamResp
sse.forEachEvent fun event => do
  IO.println event.data
```

## Dependencies

- crucible (testing)
- staple (macros)

## Examples

```bash
lake build simple_get && .lake/build/bin/simple_get
lake build post_json && .lake/build/bin/post_json
lake build client_test && .lake/build/bin/client_test
```
