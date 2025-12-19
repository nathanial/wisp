/-
  Wisp Test Runner
-/

import Wisp

/-- Check if a string contains a substring -/
def String.containsSubstr (s : String) (sub : String) : Bool :=
  (s.splitOn sub).length > 1

def main : IO UInt32 := do
  IO.println "Wisp Library Tests"
  IO.println "=================="
  IO.println ""

  -- Initialize curl
  Wisp.FFI.globalInit

  -- Test version info
  IO.println "Testing version info..."
  let version ← Wisp.FFI.versionInfo
  IO.println s!"  libcurl version: {version}"
  IO.println "  [PASS] Version info"
  IO.println ""

  -- Test simple GET request
  IO.println "Testing HTTP GET..."
  let client := Wisp.HTTP.Client.new
  let result ← client.get "https://httpbin.org/get"

  match result with
  | .ok response =>
    IO.println s!"  Status: {response.status}"
    IO.println s!"  Body size: {response.body.size} bytes"
    IO.println s!"  Time: {response.totalTime}s"
    if response.isSuccess then
      IO.println "  [PASS] GET request"
    else
      IO.println s!"  [FAIL] Unexpected status {response.status}"
      return 1
  | .error e =>
    IO.println s!"  [FAIL] Error: {e}"
    return 1

  IO.println ""

  -- Test POST with JSON
  IO.println "Testing HTTP POST JSON..."
  let jsonBody := "{\"test\": \"value\", \"number\": 42}"
  let postResult ← client.postJson "https://httpbin.org/post" jsonBody

  match postResult with
  | .ok response =>
    IO.println s!"  Status: {response.status}"
    if response.isSuccess then
      IO.println "  [PASS] POST JSON request"
    else
      IO.println s!"  [FAIL] Unexpected status {response.status}"
      return 1
  | .error e =>
    IO.println s!"  [FAIL] Error: {e}"
    return 1

  IO.println ""

  -- Test headers
  IO.println "Testing custom headers..."
  let headerReq := Wisp.Request.get "https://httpbin.org/headers"
    |>.withHeader "X-Custom-Header" "test-value"
    |>.withHeader "X-Another-Header" "another-value"
  let headerResult ← client.execute headerReq

  match headerResult with
  | .ok response =>
    IO.println s!"  Status: {response.status}"
    let body := response.bodyTextLossy
    if body.containsSubstr "X-Custom-Header" then
      IO.println "  [PASS] Custom headers"
    else
      IO.println "  [FAIL] Headers not echoed"
      return 1
  | .error e =>
    IO.println s!"  [FAIL] Error: {e}"
    return 1

  IO.println ""

  -- Cleanup
  Wisp.FFI.globalCleanup

  IO.println "=================="
  IO.println "All tests passed!"
  return 0
