/-
  HTTP POST with JSON Example
  Demonstrates POST requests with JSON body
-/

import Wisp

def main : IO Unit := do
  IO.println "Wisp POST JSON Example"
  IO.println "======================"
  IO.println ""

  Wisp.FFI.globalInit

  let client := Wisp.HTTP.Client.new
    |>.withTimeout 10000
    |>.withUserAgent "Wisp Example/1.0"

  -- Create a JSON payload
  let payload := """
{
  "name": "Lean 4",
  "version": "4.26.0",
  "features": ["dependent types", "metaprogramming", "FFI"],
  "awesome": true
}
"""

  IO.println "Sending POST request with JSON body..."
  IO.println ""

  -- Build request with builder pattern
  let req := Wisp.Request.post "https://httpbin.org/post"
    |>.withJson payload
    |>.withHeader "X-Request-Id" "12345"

  let task ← client.execute req
  let result := task.get

  match result with
  | .ok response =>
    IO.println s!"Status: {response.status}"
    IO.println s!"Time: {response.totalTime}s"
    IO.println ""
    if response.isSuccess then
      IO.println "Request successful!"
      IO.println ""
      IO.println "Response body:"
      IO.println response.bodyTextLossy
    else
      IO.println s!"Unexpected status: {response.status}"
  | .error e =>
    IO.println s!"Error: {e}"

  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown
