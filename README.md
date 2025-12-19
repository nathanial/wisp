# Wisp

A comprehensive HTTP client library for Lean 4, built on libcurl.

## Features

- **Full HTTP method support**: GET, POST, PUT, DELETE, HEAD, PATCH, OPTIONS
- **Request body types**: JSON, form-encoded, plain text, raw bytes, multipart
- **Authentication**: Basic, Bearer token, Digest
- **SSL/TLS**: Configurable verification, insecure mode, custom CA bundles
- **Redirects**: Configurable follow behavior with max redirect limits
- **Timeouts**: Request and connection timeout configuration
- **Compression**: Automatic gzip/deflate handling
- **Async execution**: Non-blocking requests via curl_multi
- **Response utilities**: Status helpers, body parsing, header access
- **Streaming responses**: Channel-based streaming for large responses
- **SSE (Server-Sent Events)**: Built-in parser for AI streaming APIs

## Installation

Add wisp as a dependency in your `lakefile.lean`:

```lean
require wisp from git "https://github.com/yourusername/wisp" @ "main"
```

### Requirements

- Lean 4.25.0 or later
- libcurl development libraries

**macOS (Homebrew):**
```bash
brew install curl
```

**Ubuntu/Debian:**
```bash
sudo apt-get install libcurl4-openssl-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install libcurl-devel
```

## Quick Start

```lean
import Wisp

def main : IO Unit := do
  -- Initialize curl (call once at startup)
  Wisp.FFI.globalInit

  let client := Wisp.HTTP.Client.new

  -- Simple GET request
  let task ← client.get "https://api.example.com/data"
  let result := task.get

  match result with
  | .ok response =>
    IO.println s!"Status: {response.status}"
    IO.println s!"Body: {response.bodyTextLossy}"
  | .error e =>
    IO.println s!"Error: {e}"

  -- Cleanup
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown
```

## API Reference

### Creating Requests

```lean
-- Simple requests
let req := Wisp.Request.get "https://example.com"
let req := Wisp.Request.post "https://example.com"
let req := Wisp.Request.put "https://example.com"
let req := Wisp.Request.delete "https://example.com"
let req := Wisp.Request.head "https://example.com"
let req := Wisp.Request.patch "https://example.com"
let req := Wisp.Request.options "https://example.com"
```

### Request Bodies

```lean
-- JSON body
let req := Wisp.Request.post url |>.withJson """{"key": "value"}"""

-- Form-encoded body
let req := Wisp.Request.post url |>.withForm #[("field", "value")]

-- Plain text
let req := Wisp.Request.post url |>.withText "Hello, World!"

-- Raw bytes with content type
let req := Wisp.Request.post url |>.withBody bytes "application/octet-stream"

-- Multipart form (file uploads)
let parts : Array Wisp.MultipartPart := #[
  { name := "file", filename := some "data.txt", data := contents.toUTF8 }
]
let req := Wisp.Request.post url |>.withMultipart parts
```

### Headers

```lean
let req := Wisp.Request.get url
  |>.withHeader "X-Custom-Header" "value"
  |>.withHeader "Accept" "application/json"
```

### Authentication

```lean
-- Basic auth
let req := Wisp.Request.get url |>.withBasicAuth "username" "password"

-- Bearer token
let req := Wisp.Request.get url |>.withBearerToken "your-token"

-- Digest auth
let req := Wisp.Request.get url |>.withDigestAuth "username" "password"
```

### Timeouts

```lean
-- Request timeout (milliseconds)
let req := Wisp.Request.get url |>.withTimeout 5000

-- Connection timeout (milliseconds)
let req := Wisp.Request.get url |>.withConnectTimeout 3000
```

### Redirects

```lean
-- Disable redirect following
let req := Wisp.Request.get url |>.withFollowRedirects false

-- Limit redirects
let req := Wisp.Request.get url |>.withFollowRedirects true 5
```

### SSL Options

```lean
-- Disable SSL verification (use with caution!)
let req := Wisp.Request.get url |>.withInsecure

-- Custom SSL options
let req := Wisp.Request.get url |>.withSsl {
  verifyPeer := true,
  verifyHost := true,
  caCertPath := some "/path/to/ca-bundle.crt"
}
```

### Executing Requests

```lean
let client := Wisp.HTTP.Client.new

-- Async execution (returns Task)
let task ← client.execute req
let result := task.get

-- Convenience methods
let task ← client.get "https://example.com"
let task ← client.postJson "https://example.com" """{"key": "value"}"""
let task ← client.postForm "https://example.com" #[("field", "value")]
let task ← client.putJson "https://example.com" """{"key": "value"}"""
let task ← client.delete "https://example.com"
let task ← client.head "https://example.com"
```

### Working with Responses

```lean
match result with
| .ok response =>
  -- Status code
  let status := response.status  -- UInt32

  -- Status helpers
  let _ := response.isSuccess     -- 2xx
  let _ := response.isRedirect    -- 3xx
  let _ := response.isClientError -- 4xx
  let _ := response.isServerError -- 5xx
  let _ := response.isError       -- 4xx or 5xx
  let _ := response.statusText    -- "OK", "Not Found", etc.

  -- Body access
  let text := response.bodyText      -- Option String (strict UTF-8)
  let text := response.bodyTextLossy -- String (replaces invalid bytes)
  let bytes := response.body         -- ByteArray
  let size := response.bodySize      -- Nat
  let empty := response.isEmpty      -- Bool

  -- Headers
  let ct := response.contentType           -- Option String
  let val := response.header "X-Custom"    -- Option String
  let headers := response.headers          -- Array (String × String)

  -- Metadata
  let time := response.totalTime      -- Float (seconds)
  let url := response.effectiveUrl    -- String (after redirects)

| .error e =>
  IO.println s!"Error: {e}"
```

### Error Types

```lean
inductive WispError where
  | curlError (msg : String)
  | httpError (status : UInt32) (msg : String)
  | timeoutError (msg : String)
  | connectionError (msg : String)
  | sslError (msg : String)
  | ioError (msg : String)
```

### Streaming Responses

For large responses or real-time data, use streaming to process data as it arrives:

```lean
let client := Wisp.HTTP.Client.new
let req := Wisp.Request.get "https://example.com/large-file"

-- Execute with streaming
let task ← client.executeStreaming req
match task.get with
| .ok stream =>
  -- Status and headers available immediately
  IO.println s!"Status: {stream.status}"
  IO.println s!"Content-Type: {stream.contentType}"

  -- Process chunks as they arrive
  stream.forEachChunk fun chunk => do
    IO.print (String.fromUTF8! chunk)

  -- Or read all at once
  let body ← stream.readAllBody
  let text ← stream.readAllBodyText

| .error e =>
  IO.println s!"Error: {e}"
```

The `StreamingResponse` type provides:
- `status` - HTTP status code (available immediately after headers)
- `headers` - Response headers
- `contentType` - Content-Type header value
- `bodyChannel` - Channel that yields `ByteArray` chunks
- `readAllBody` - Read entire body as `ByteArray`
- `readAllBodyText` - Read entire body as `String`
- `forEachChunk` - Iterate over chunks as they arrive

### SSE (Server-Sent Events)

Parse Server-Sent Events for AI streaming APIs (OpenAI, Anthropic, etc.):

```lean
let client := Wisp.HTTP.Client.new

-- Make streaming request to SSE endpoint
let req := Wisp.Request.post "https://api.openai.com/v1/chat/completions"
  |>.withBearerToken apiKey
  |>.withJson """{"model": "gpt-4", "messages": [...], "stream": true}"""

let task ← client.executeStreaming req
match task.get with
| .ok streamResp =>
  -- Create SSE stream from response
  let sse ← Wisp.HTTP.SSE.Stream.fromStreaming streamResp

  -- Process events as they arrive
  sse.forEachEvent fun event => do
    IO.println s!"Event type: {event.event}"
    IO.println s!"Data: {event.data}"
    if let some id := event.id then
      IO.println s!"ID: {id}"

  -- Or read one event at a time
  let event? ← sse.recv
  match event? with
  | some event => IO.println event.data
  | none => IO.println "Stream ended"

  -- Track last event ID (for reconnection)
  let lastId ← sse.getLastEventId

| .error e =>
  IO.println s!"Error: {e}"
```

SSE Event structure:
```lean
structure SSE.Event where
  event : String := "message"  -- Event type
  data : String                -- Event data (multiple lines joined)
  id : Option String           -- Event ID
  retry : Option Nat           -- Retry interval (ms)
```

## Examples

See the `examples/` directory:

- `SimpleGet.lean` - Basic GET request
- `PostJSON.lean` - POST with JSON body
- `ClientTest.lean` - Step-by-step client usage

Run examples:
```bash
lake build simple_get && .lake/build/bin/simple_get
lake build post_json && .lake/build/bin/post_json
```

## Testing

Run the test suite:
```bash
lake test
```

The test suite includes 74 tests covering:
- All HTTP methods
- Request body types
- Authentication methods
- Redirect handling
- Timeout behavior
- Status code handling
- Response parsing
- SSL options
- URL encoding
- Streaming responses
- SSE parsing

## Architecture

```
Wisp/
├── Core/
│   ├── Types.lean      # Method, Headers, URL types
│   ├── Error.lean      # WispError, WispResult
│   ├── Request.lean    # Request builder
│   ├── Response.lean   # Response type and helpers
│   └── Streaming.lean  # StreamingResponse type
├── FFI/
│   ├── Easy.lean       # curl_easy_* bindings
│   └── Multi.lean      # curl_multi_* bindings
└── HTTP/
    ├── Client.lean     # High-level HTTP client
    └── SSE.lean        # Server-Sent Events parser
```

## License

MIT License - see [LICENSE](LICENSE)
