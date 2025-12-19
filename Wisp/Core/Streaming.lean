/-
  Wisp Streaming Types
  Types for streaming HTTP responses
-/

import Wisp.Core.Types
import Std.Sync.Channel

namespace Wisp

/-- A streaming HTTP response -/
structure StreamingResponse where
  /-- HTTP status code -/
  status : UInt32
  /-- Response headers -/
  headers : Headers
  /-- Content-Type from headers -/
  contentType : Option String := none
  /-- Channel for receiving body chunks. Closes when stream ends. -/
  bodyChannel : Std.CloseableChannel.Sync ByteArray
  /-- Effective URL after redirects -/
  effectiveUrl : String := ""

namespace StreamingResponse

/-- Check if response status indicates success (2xx) -/
def isSuccess (r : StreamingResponse) : Bool :=
  r.status >= 200 && r.status < 300

/-- Check if response status indicates redirect (3xx) -/
def isRedirect (r : StreamingResponse) : Bool :=
  r.status >= 300 && r.status < 400

/-- Check if response status indicates client error (4xx) -/
def isClientError (r : StreamingResponse) : Bool :=
  r.status >= 400 && r.status < 500

/-- Check if response status indicates server error (5xx) -/
def isServerError (r : StreamingResponse) : Bool :=
  r.status >= 500 && r.status < 600

/-- Check if response indicates any error (4xx or 5xx) -/
def isError (r : StreamingResponse) : Bool :=
  r.status >= 400

/-- Get header value by name (case-insensitive) -/
def header (r : StreamingResponse) (name : String) : Option String :=
  r.headers.get? name

/-- Read all chunks from the body channel, concatenating into a single ByteArray -/
partial def readAllBody (r : StreamingResponse) : IO ByteArray := do
  let rec loop (acc : ByteArray) : IO ByteArray := do
    let chunk? ← r.bodyChannel.recv
    match chunk? with
    | some chunk =>
      loop (acc ++ chunk)
    | none =>
      return acc
  loop ByteArray.empty

/-- Read all chunks and convert to string -/
def readAllBodyText (r : StreamingResponse) : IO (Option String) := do
  let body ← r.readAllBody
  return String.fromUTF8? body

/-- Iterate over each chunk as it arrives -/
partial def forEachChunk (r : StreamingResponse) (f : ByteArray → IO Unit) : IO Unit := do
  let rec loop : IO Unit := do
    let chunk? ← r.bodyChannel.recv
    match chunk? with
    | some chunk =>
      f chunk
      loop
    | none =>
      return ()
  loop

end StreamingResponse

end Wisp
