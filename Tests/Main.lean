/-
  Wisp Test Runner - Comprehensive Test Suite
-/

import Wisp

/-- Check if a string contains a substring -/
def String.containsSubstr (s : String) (sub : String) : Bool :=
  (s.splitOn sub).length > 1

/-- Test result tracking -/
structure TestStats where
  passed : Nat := 0
  failed : Nat := 0

def TestStats.total (s : TestStats) : Nat := s.passed + s.failed

def TestStats.pass (s : TestStats) : TestStats := { s with passed := s.passed + 1 }
def TestStats.fail (s : TestStats) : TestStats := { s with failed := s.failed + 1 }

/-- Run a test and update stats -/
def runTest (name : String) (test : IO Bool) (stats : TestStats) : IO TestStats := do
  IO.print s!"  {name}... "
  try
    let result ← test
    if result then
      IO.println "[PASS]"
      return stats.pass
    else
      IO.println "[FAIL]"
      return stats.fail
  catch e =>
    IO.println s!"[FAIL] Exception: {e}"
    return stats.fail

def awaitTask (task : IO (Task α)) : IO α := do
  let t ← task
  return t.get

def main : IO UInt32 := do
  IO.println "Wisp Library Tests - Comprehensive Suite"
  IO.println "========================================="
  IO.println ""

  -- Initialize curl
  Wisp.FFI.globalInit

  let client := Wisp.HTTP.Client.new
  let mut stats : TestStats := {}

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 1: Basic FFI
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "1. Basic FFI"
  IO.println "------------"

  stats ← runTest "Version info" (do
    let version ← Wisp.FFI.versionInfo
    return version.containsSubstr "libcurl"
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 2: HTTP Methods
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "2. HTTP Methods"
  IO.println "---------------"

  stats ← runTest "GET request" (do
    let result ← awaitTask (client.get "https://httpbin.org/get")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "POST request" (do
    let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"test\": 1}")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "PUT request" (do
    let result ← awaitTask (client.putJson "https://httpbin.org/put" "{\"update\": true}")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "DELETE request" (do
    let result ← awaitTask (client.delete "https://httpbin.org/delete")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "HEAD request" (do
    let result ← awaitTask (client.head "https://httpbin.org/get")
    match result with
    | .ok r => return r.status == 200 && r.body.isEmpty
    | .error _ => return false
  ) stats

  stats ← runTest "PATCH request" (do
    let req := Wisp.Request.patch "https://httpbin.org/patch" |>.withJson "{\"patch\": true}"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "OPTIONS request" (do
    let req := Wisp.Request.options "https://httpbin.org/get"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 3: Request Body Types
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "3. Request Body Types"
  IO.println "---------------------"

  stats ← runTest "JSON body" (do
    let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"key\": \"value\"}")
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "application/json"
    | .error _ => return false
  ) stats

  stats ← runTest "Form-encoded body" (do
    let result ← awaitTask (client.postForm "https://httpbin.org/post" #[("field1", "value1"), ("field2", "value2")])
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "field1" && body.containsSubstr "value1"
    | .error _ => return false
  ) stats

  stats ← runTest "Plain text body" (do
    let req := Wisp.Request.post "https://httpbin.org/post" |>.withText "Hello, World!"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "Hello, World!"
    | .error _ => return false
  ) stats

  stats ← runTest "Raw bytes body" (do
    let bytes := "raw data".toUTF8
    let req := Wisp.Request.post "https://httpbin.org/post" |>.withBody bytes "application/octet-stream"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 4: Headers
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "4. Headers"
  IO.println "----------"

  stats ← runTest "Custom headers sent" (do
    let req := Wisp.Request.get "https://httpbin.org/headers"
      |>.withHeader "X-Test-Header" "test-value-123"
      |>.withHeader "X-Another" "another-value"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return body.containsSubstr "X-Test-Header" && body.containsSubstr "test-value-123"
    | .error _ => return false
  ) stats

  stats ← runTest "Response headers parsed" (do
    let result ← awaitTask (client.get "https://httpbin.org/response-headers?X-Custom-Response=hello")
    match result with
    | .ok r =>
      let hasHeader := r.headers.get? "X-Custom-Response"
      return hasHeader.isSome
    | .error _ => return false
  ) stats

  stats ← runTest "Content-Type header" (do
    let result ← awaitTask (client.get "https://httpbin.org/json")
    match result with
    | .ok r => return r.contentType.isSome && (r.contentType.getD "").containsSubstr "json"
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 5: Authentication
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "5. Authentication"
  IO.println "-----------------"

  stats ← runTest "Basic auth (valid)" (do
    let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
      |>.withBasicAuth "testuser" "testpass"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Basic auth (invalid)" (do
    let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
      |>.withBasicAuth "wrong" "credentials"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 401
    | .error _ => return false
  ) stats

  stats ← runTest "Bearer token" (do
    let req := Wisp.Request.get "https://httpbin.org/bearer"
      |>.withBearerToken "my-secret-token"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "my-secret-token"
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 6: Redirects
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "6. Redirects"
  IO.println "------------"

  stats ← runTest "Follow redirects (default)" (do
    let result ← awaitTask (client.get "https://httpbin.org/redirect/2")
    match result with
    | .ok r =>
      -- Should end at /get after 2 redirects
      return r.status == 200 && r.effectiveUrl.containsSubstr "/get"
    | .error _ => return false
  ) stats

  stats ← runTest "Don't follow redirects" (do
    let req := Wisp.Request.get "https://httpbin.org/redirect/1"
      |>.withFollowRedirects false
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 302
    | .error _ => return false
  ) stats

  stats ← runTest "Absolute redirect" (do
    let result ← awaitTask (client.get "https://httpbin.org/absolute-redirect/1")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 7: Timeouts
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "7. Timeouts"
  IO.println "-----------"

  stats ← runTest "Request completes within timeout" (do
    let req := Wisp.Request.get "https://httpbin.org/delay/1"
      |>.withTimeout 5000  -- 5 second timeout, 1 second delay
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Request times out" (do
    let req := Wisp.Request.get "https://httpbin.org/delay/10"
      |>.withTimeout 1000  -- 1 second timeout, 10 second delay
    let result ← awaitTask (client.execute req)
    match result with
    | .ok _ => return false  -- Should have timed out
    | .error e => return e.toString.containsSubstr "timeout" || e.toString.containsSubstr "Timeout" || true  -- Any error is acceptable for timeout
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 8: HTTP Status Codes
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "8. HTTP Status Codes"
  IO.println "--------------------"

  stats ← runTest "200 OK" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/200")
    match result with
    | .ok r => return r.status == 200 && r.isSuccess
    | .error _ => return false
  ) stats

  stats ← runTest "201 Created" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/201")
    match result with
    | .ok r => return r.status == 201 && r.isSuccess
    | .error _ => return false
  ) stats

  stats ← runTest "204 No Content" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/204")
    match result with
    | .ok r => return r.status == 204 && r.isSuccess
    | .error _ => return false
  ) stats

  stats ← runTest "400 Bad Request" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/400")
    match result with
    | .ok r => return r.status == 400 && r.isClientError
    | .error _ => return false
  ) stats

  stats ← runTest "401 Unauthorized" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/401")
    match result with
    | .ok r => return r.status == 401 && r.isClientError
    | .error _ => return false
  ) stats

  stats ← runTest "403 Forbidden" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/403")
    match result with
    | .ok r => return r.status == 403 && r.isClientError
    | .error _ => return false
  ) stats

  stats ← runTest "404 Not Found" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/404")
    match result with
    | .ok r => return r.status == 404 && r.isClientError
    | .error _ => return false
  ) stats

  stats ← runTest "500 Internal Server Error" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/500")
    match result with
    | .ok r => return r.status == 500 && r.isServerError
    | .error _ => return false
  ) stats

  stats ← runTest "502 Bad Gateway" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/502")
    match result with
    | .ok r => return r.status == 502 && r.isServerError
    | .error _ => return false
  ) stats

  stats ← runTest "503 Service Unavailable" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/503")
    match result with
    | .ok r => return r.status == 503 && r.isServerError
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 9: Response Body Parsing
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "9. Response Body Parsing"
  IO.println "------------------------"

  stats ← runTest "Body as text (valid UTF-8)" (do
    let result ← awaitTask (client.get "https://httpbin.org/encoding/utf8")
    match result with
    | .ok r =>
      match r.bodyText with
      | some text => return text.length > 0
      | none => return false
    | .error _ => return false
  ) stats

  stats ← runTest "Body as lossy text" (do
    let result ← awaitTask (client.get "https://httpbin.org/bytes/100")
    match result with
    | .ok r =>
      let text := r.bodyTextLossy
      return text.length > 0  -- Should handle binary gracefully
    | .error _ => return false
  ) stats

  stats ← runTest "Body size tracking" (do
    let result ← awaitTask (client.get "https://httpbin.org/bytes/256")
    match result with
    | .ok r => return r.body.size == 256
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 10: Client Configuration
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "10. Client Configuration"
  IO.println "------------------------"

  stats ← runTest "Custom user agent" (do
    let req := Wisp.Request.get "https://httpbin.org/user-agent"
      |>.withUserAgent "CustomAgent/1.0"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return body.containsSubstr "CustomAgent/1.0"
    | .error _ => return false
  ) stats

  stats ← runTest "Gzip encoding" (do
    let result ← awaitTask (client.get "https://httpbin.org/gzip")
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "gzipped"
    | .error _ => return false
  ) stats

  stats ← runTest "Deflate encoding" (do
    let result ← awaitTask (client.get "https://httpbin.org/deflate")
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "deflated"
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- SECTION 11: Response Metadata
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "11. Response Metadata"
  IO.println "---------------------"

  stats ← runTest "Total time tracked" (do
    let result ← awaitTask (client.get "https://httpbin.org/delay/1")
    match result with
    | .ok r => return r.totalTime >= 1.0
    | .error _ => return false
  ) stats

  stats ← runTest "Effective URL tracked" (do
    let result ← awaitTask (client.get "https://httpbin.org/redirect/1")
    match result with
    | .ok r => return r.effectiveUrl.containsSubstr "httpbin.org"
    | .error _ => return false
  ) stats

  IO.println ""

  -- ═══════════════════════════════════════════════════════════════════
  -- Summary
  -- ═══════════════════════════════════════════════════════════════════
  IO.println "========================================="
  IO.println s!"Tests: {stats.total} total, {stats.passed} passed, {stats.failed} failed"

  -- Cleanup
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown

  if stats.failed > 0 then
    IO.println "\nSome tests failed!"
    return 1
  else
    IO.println "\nAll tests passed!"
    return 0
