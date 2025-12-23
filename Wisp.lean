/-
  Wisp - Lean 4 HTTP/Curl Library

  A comprehensive wrapper around libcurl providing:
  - Full curl protocol support (HTTP, FTP, SFTP, SMTP, WebSocket, etc.)
  - High-level typed API with builder pattern
  - Async support via curl_multi

  Basic usage:
  ```
  let client := Wisp.HTTP.Client.new
  let task ← client.get "https://example.com"
  let response := task.get
  ```
-/

import Wisp.Core.Types
import Wisp.Core.Error
import Wisp.Core.Request
import Wisp.Core.Response
import Wisp.Core.Streaming
import Wisp.Core.WebSocket
import Wisp.FFI.Easy
import Wisp.FFI.Multi
import Wisp.HTTP.Client
import Wisp.HTTP.SSE
import Wisp.HTTP.WebSocket
