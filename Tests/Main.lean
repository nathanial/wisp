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
def TestStats.merge (s1 s2 : TestStats) : TestStats :=
  { passed := s1.passed + s2.passed, failed := s1.failed + s2.failed }

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

-- ═══════════════════════════════════════════════════════════════════════════
-- Test Sections
-- ═══════════════════════════════════════════════════════════════════════════

def testBasicFFI : IO TestStats := do
  IO.println "1. Basic FFI"
  IO.println "------------"
  let mut stats : TestStats := {}

  stats ← runTest "Version info" (do
    let version ← Wisp.FFI.versionInfo
    return version.containsSubstr "libcurl"
  ) stats

  IO.println ""
  return stats

def testHTTPMethods (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "2. HTTP Methods"
  IO.println "---------------"
  let mut stats : TestStats := {}

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
  return stats

def testRequestBodyTypes (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "3. Request Body Types"
  IO.println "---------------------"
  let mut stats : TestStats := {}

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
  return stats

def testHeaders (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "4. Headers"
  IO.println "----------"
  let mut stats : TestStats := {}

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
  return stats

def testAuthentication (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "5. Authentication"
  IO.println "-----------------"
  let mut stats : TestStats := {}

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
  return stats

def testRedirects (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "6. Redirects"
  IO.println "------------"
  let mut stats : TestStats := {}

  stats ← runTest "Follow redirects (default)" (do
    let result ← awaitTask (client.get "https://httpbin.org/redirect/2")
    match result with
    | .ok r =>
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
  return stats

def testTimeouts (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "7. Timeouts"
  IO.println "-----------"
  let mut stats : TestStats := {}

  stats ← runTest "Request completes within timeout" (do
    let req := Wisp.Request.get "https://httpbin.org/delay/1"
      |>.withTimeout 5000
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Request times out" (do
    let req := Wisp.Request.get "https://httpbin.org/delay/10"
      |>.withTimeout 1000
    let result ← awaitTask (client.execute req)
    match result with
    | .ok _ => return false
    | .error _ => return true
  ) stats

  IO.println ""
  return stats

def testHTTPStatusCodes (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "8. HTTP Status Codes"
  IO.println "--------------------"
  let mut stats : TestStats := {}

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
  return stats

def testResponseBodyParsing (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "9. Response Body Parsing"
  IO.println "------------------------"
  let mut stats : TestStats := {}

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
      return text.length > 0
    | .error _ => return false
  ) stats

  stats ← runTest "Body size tracking" (do
    let result ← awaitTask (client.get "https://httpbin.org/bytes/256")
    match result with
    | .ok r => return r.body.size == 256
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testClientConfiguration (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "10. Client Configuration"
  IO.println "------------------------"
  let mut stats : TestStats := {}

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
  return stats

def testResponseMetadata (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "11. Response Metadata"
  IO.println "---------------------"
  let mut stats : TestStats := {}

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
  return stats

def testMultipartUploads (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "12. Multipart Form Uploads"
  IO.println "--------------------------"
  let mut stats : TestStats := {}

  stats ← runTest "Multipart text field" (do
    let parts : Array Wisp.MultipartPart := #[
      { name := "field1", data := "value1".toUTF8 },
      { name := "field2", data := "value2".toUTF8 }
    ]
    let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "field1" && body.containsSubstr "value1"
    | .error _ => return false
  ) stats

  stats ← runTest "Multipart with filename" (do
    let parts : Array Wisp.MultipartPart := #[
      { name := "file", filename := some "test.txt", contentType := some "text/plain", data := "file contents here".toUTF8 }
    ]
    let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      -- httpbin puts file contents in "files" section
      return r.status == 200 && body.containsSubstr "files" && body.containsSubstr "file contents here"
    | .error _ => return false
  ) stats

  stats ← runTest "Multipart with content type" (do
    let parts : Array Wisp.MultipartPart := #[
      { name := "jsondata", contentType := some "application/json", data := "{\"key\": \"value\"}".toUTF8 }
    ]
    let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      -- httpbin puts non-file multipart data in "form" section
      return r.status == 200 && body.containsSubstr "jsondata"
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testDigestAuth (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "13. Digest Authentication"
  IO.println "-------------------------"
  let mut stats : TestStats := {}

  stats ← runTest "Digest auth (valid)" (do
    let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
      |>.withDigestAuth "testuser" "testpass"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Digest auth (invalid)" (do
    let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
      |>.withDigestAuth "wrong" "credentials"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 401
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testConnectionTimeout (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "14. Connection Timeout"
  IO.println "----------------------"
  let mut stats : TestStats := {}

  stats ← runTest "Connection timeout setting" (do
    let req := Wisp.Request.get "https://httpbin.org/get"
      |>.withConnectTimeout 5000
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testSSLOptions (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "15. SSL Options"
  IO.println "---------------"
  let mut stats : TestStats := {}

  stats ← runTest "SSL verification enabled (default)" (do
    let result ← awaitTask (client.get "https://httpbin.org/get")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "SSL insecure mode" (do
    let req := Wisp.Request.get "https://httpbin.org/get"
      |>.withInsecure
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testResponseHelpers (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "16. Response Helper Functions"
  IO.println "-----------------------------"
  let mut stats : TestStats := {}

  stats ← runTest "isRedirect for 302" (do
    let req := Wisp.Request.get "https://httpbin.org/redirect/1"
      |>.withFollowRedirects false
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.isRedirect
    | .error _ => return false
  ) stats

  stats ← runTest "isError for 4xx/5xx" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/404")
    match result with
    | .ok r => return r.isError
    | .error _ => return false
  ) stats

  stats ← runTest "isEmpty for empty body" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/204")
    match result with
    | .ok r => return r.isEmpty
    | .error _ => return false
  ) stats

  stats ← runTest "statusText for known codes" (do
    let result ← awaitTask (client.get "https://httpbin.org/status/404")
    match result with
    | .ok r => return r.statusText == "Not Found"
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testCookies (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "17. Cookies"
  IO.println "-----------"
  let mut stats : TestStats := {}

  stats ← runTest "Set-Cookie in response headers" (do
    let result ← awaitTask (client.get "https://httpbin.org/cookies/set/testcookie/testvalue")
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Send cookie via header" (do
    let req := Wisp.Request.get "https://httpbin.org/cookies"
      |>.withHeader "Cookie" "mycookie=myvalue"
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "mycookie" && body.containsSubstr "myvalue"
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testMaxRedirects (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "18. Max Redirects Limit"
  IO.println "-----------------------"
  let mut stats : TestStats := {}

  stats ← runTest "Max redirects respected" (do
    let req := Wisp.Request.get "https://httpbin.org/redirect/5"
      |>.withFollowRedirects true 2
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.isRedirect || r.status == 302
    | .error _ => return true  -- Curl error for too many redirects is acceptable
  ) stats

  stats ← runTest "Sufficient redirects allowed" (do
    let req := Wisp.Request.get "https://httpbin.org/redirect/2"
      |>.withFollowRedirects true 5
    let result ← awaitTask (client.execute req)
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

def testURLEncoding (client : Wisp.HTTP.Client) : IO TestStats := do
  IO.println "19. URL Encoding Edge Cases"
  IO.println "---------------------------"
  let mut stats : TestStats := {}

  stats ← runTest "Form field with special chars" (do
    let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
      ("name", "John Doe"),
      ("email", "john+test@example.com"),
      ("query", "a=b&c=d")
    ])
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "John" && body.containsSubstr "example.com"
    | .error _ => return false
  ) stats

  stats ← runTest "Form field with unicode" (do
    let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
      ("greeting", "Héllo Wörld"),
      ("emoji", "👋")
    ])
    match result with
    | .ok r => return r.status == 200
    | .error _ => return false
  ) stats

  stats ← runTest "Empty form field" (do
    let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
      ("empty", ""),
      ("nonempty", "value")
    ])
    match result with
    | .ok r =>
      let body := r.bodyTextLossy
      return r.status == 200 && body.containsSubstr "nonempty"
    | .error _ => return false
  ) stats

  IO.println ""
  return stats

-- ═══════════════════════════════════════════════════════════════════════════
-- Main
-- ═══════════════════════════════════════════════════════════════════════════

def main : IO UInt32 := do
  IO.println "Wisp Library Tests - Comprehensive Suite"
  IO.println "========================================="
  IO.println ""

  -- Initialize curl
  Wisp.FFI.globalInit

  let client := Wisp.HTTP.Client.new

  -- Run all test sections
  let s1 ← testBasicFFI
  let s2 ← testHTTPMethods client
  let s3 ← testRequestBodyTypes client
  let s4 ← testHeaders client
  let s5 ← testAuthentication client
  let s6 ← testRedirects client
  let s7 ← testTimeouts client
  let s8 ← testHTTPStatusCodes client
  let s9 ← testResponseBodyParsing client
  let s10 ← testClientConfiguration client
  let s11 ← testResponseMetadata client
  let s12 ← testMultipartUploads client
  let s13 ← testDigestAuth client
  let s14 ← testConnectionTimeout client
  let s15 ← testSSLOptions client
  let s16 ← testResponseHelpers client
  let s17 ← testCookies client
  let s18 ← testMaxRedirects client
  let s19 ← testURLEncoding client

  -- Merge all stats
  let stats := s1.merge s2 |>.merge s3 |>.merge s4 |>.merge s5
    |>.merge s6 |>.merge s7 |>.merge s8 |>.merge s9 |>.merge s10
    |>.merge s11 |>.merge s12 |>.merge s13 |>.merge s14 |>.merge s15
    |>.merge s16 |>.merge s17 |>.merge s18 |>.merge s19

  -- Summary
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
