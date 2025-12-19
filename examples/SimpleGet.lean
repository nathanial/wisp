/-
  Simple HTTP GET Example
  Demonstrates basic usage of the Wisp HTTP client
-/

import Wisp

def main : IO Unit := do
  IO.println "Wisp Simple GET Example"
  IO.println "======================="
  IO.println ""

  -- Initialize (happens automatically, but explicit for clarity)
  Wisp.FFI.globalInit

  -- Create a client
  let client := Wisp.HTTP.Client.new

  -- Make a GET request
  IO.println "Fetching https://httpbin.org/get ..."
  let task ← client.get "https://httpbin.org/get"
  let result := task.get

  match result with
  | .ok response =>
    IO.println ""
    IO.println s!"Status: {response.status} ({response.statusText})"
    IO.println s!"Content-Type: {response.contentType.getD "unknown"}"
    IO.println s!"Body size: {response.body.size} bytes"
    IO.println s!"Total time: {response.totalTime}s"
    IO.println s!"Effective URL: {response.effectiveUrl}"
    IO.println ""
    IO.println "Response headers:"
    for (key, value) in response.headers do
      IO.println s!"  {key}: {value}"
    IO.println ""
    IO.println "Response body (first 500 chars):"
    let body := response.bodyTextLossy
    IO.println (body.take 500)
  | .error e =>
    IO.println s!"Error: {e}"

  -- Cleanup
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown
