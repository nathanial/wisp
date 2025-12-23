/-
  Wisp Test Runner - Comprehensive Test Suite
  Using Crucible Test Framework
-/

import Wisp
import Crucible

open Crucible

/-- Check if a string contains a substring -/
def String.containsSubstr (s : String) (sub : String) : Bool :=
  (s.splitOn sub).length > 1

def awaitTask (task : IO (Task α)) : IO α := do
  let t ← task
  return t.get

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new

-- ═══════════════════════════════════════════════════════════════════════════
-- Test Sections
-- ═══════════════════════════════════════════════════════════════════════════

namespace Tests.BasicFFI

testSuite "Basic FFI"

test "Version info" := do
  let version ← Wisp.FFI.versionInfo
  shouldSatisfy (version.containsSubstr "libcurl") "version contains libcurl"

#generate_tests

end Tests.BasicFFI

namespace Tests.HTTPMethods

testSuite "HTTP Methods"

test "GET request" := do
  let result ← awaitTask (client.get "https://httpbin.org/get")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "POST request" := do
  let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"test\": 1}")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "PUT request" := do
  let result ← awaitTask (client.putJson "https://httpbin.org/put" "{\"update\": true}")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "DELETE request" := do
  let result ← awaitTask (client.delete "https://httpbin.org/delete")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "HEAD request" := do
  let result ← awaitTask (client.head "https://httpbin.org/get")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy r.body.isEmpty "HEAD response body is empty"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "PATCH request" := do
  let req := Wisp.Request.patch "https://httpbin.org/patch" |>.withJson "{\"patch\": true}"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "OPTIONS request" := do
  let req := Wisp.Request.options "https://httpbin.org/get"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.HTTPMethods

namespace Tests.RequestBodies

testSuite "Request Body Types"

test "JSON body" := do
  let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"key\": \"value\"}")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "application/json") "response contains application/json"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Form-encoded body" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[("field1", "value1"), ("field2", "value2")])
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "field1") "response contains field1"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "value1") "response contains value1"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Plain text body" := do
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withText "Hello, World!"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "Hello, World!") "response contains Hello, World!"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Raw bytes body" := do
  let bytes := "raw data".toUTF8
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withBody bytes "application/octet-stream"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.RequestBodies

namespace Tests.Headers

testSuite "Headers"

test "Custom headers sent" := do
  let req := Wisp.Request.get "https://httpbin.org/headers"
    |>.withHeader "X-Test-Header" "test-value-123"
    |>.withHeader "X-Another" "another-value"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    shouldSatisfy (r.bodyTextLossy.containsSubstr "X-Test-Header") "response contains X-Test-Header"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "test-value-123") "response contains test-value-123"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Response headers parsed" := do
  let result ← awaitTask (client.get "https://httpbin.org/response-headers?X-Custom-Response=hello")
  match result with
  | .ok r =>
    shouldSatisfy (r.headers.get? "X-Custom-Response").isSome "X-Custom-Response header present"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Content-Type header" := do
  let result ← awaitTask (client.get "https://httpbin.org/json")
  match result with
  | .ok r =>
    shouldSatisfy r.contentType.isSome "Content-Type header present"
    shouldSatisfy ((r.contentType.getD "").containsSubstr "json") "Content-Type contains json"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Headers

namespace Tests.Authentication

testSuite "Authentication"

test "Basic auth (valid)" := do
  let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
    |>.withBasicAuth "testuser" "testpass"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Basic auth (invalid)" := do
  let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
    |>.withBasicAuth "wrong" "credentials"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 401
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Bearer token" := do
  let req := Wisp.Request.get "https://httpbin.org/bearer"
    |>.withBearerToken "my-secret-token"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "my-secret-token") "response contains token"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Authentication

namespace Tests.Redirects

testSuite "Redirects"

test "Follow redirects (default)" := do
  let result ← awaitTask (client.get "https://httpbin.org/redirect/2")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.effectiveUrl.containsSubstr "/get") "redirected to /get"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Don't follow redirects" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/1"
    |>.withFollowRedirects false
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 302
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Absolute redirect" := do
  let result ← awaitTask (client.get "https://httpbin.org/absolute-redirect/1")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Redirects

namespace Tests.Timeouts

testSuite "Timeouts"

test "Request completes within timeout" := do
  let req := Wisp.Request.get "https://httpbin.org/delay/1"
    |>.withTimeout 5000
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Request times out" := do
  let req := Wisp.Request.get "https://httpbin.org/delay/10"
    |>.withTimeout 1000
  let result ← awaitTask (client.execute req)
  match result with
  | .ok _ => throw (IO.userError "Expected timeout but request succeeded")
  | .error _ => pure ()  -- Timeout is expected

#generate_tests

end Tests.Timeouts

namespace Tests.StatusCodes

testSuite "HTTP Status Codes"

test "200 OK" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/200")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy r.isSuccess "isSuccess"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "201 Created" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/201")
  match result with
  | .ok r =>
    r.status ≡ 201
    shouldSatisfy r.isSuccess "isSuccess"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "204 No Content" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/204")
  match result with
  | .ok r =>
    r.status ≡ 204
    shouldSatisfy r.isSuccess "isSuccess"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "400 Bad Request" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/400")
  match result with
  | .ok r =>
    r.status ≡ 400
    shouldSatisfy r.isClientError "isClientError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "401 Unauthorized" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/401")
  match result with
  | .ok r =>
    r.status ≡ 401
    shouldSatisfy r.isClientError "isClientError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "403 Forbidden" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/403")
  match result with
  | .ok r =>
    r.status ≡ 403
    shouldSatisfy r.isClientError "isClientError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "404 Not Found" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  match result with
  | .ok r =>
    r.status ≡ 404
    shouldSatisfy r.isClientError "isClientError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "500 Internal Server Error" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/500")
  match result with
  | .ok r =>
    r.status ≡ 500
    shouldSatisfy r.isServerError "isServerError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "502 Bad Gateway" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/502")
  match result with
  | .ok r =>
    r.status ≡ 502
    shouldSatisfy r.isServerError "isServerError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "503 Service Unavailable" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/503")
  match result with
  | .ok r =>
    r.status ≡ 503
    shouldSatisfy r.isServerError "isServerError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.StatusCodes

namespace Tests.ResponseParsing

testSuite "Response Body Parsing"

test "Body as text (valid UTF-8)" := do
  let result ← awaitTask (client.get "https://httpbin.org/encoding/utf8")
  match result with
  | .ok r =>
    match r.bodyText with
    | some text => shouldSatisfy (text.length > 0) "body has content"
    | none => throw (IO.userError "Expected valid UTF-8 body")
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Body as lossy text" := do
  let result ← awaitTask (client.get "https://httpbin.org/bytes/100")
  match result with
  | .ok r => shouldSatisfy (r.bodyTextLossy.length > 0) "lossy text has content"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Body size tracking" := do
  let result ← awaitTask (client.get "https://httpbin.org/bytes/256")
  match result with
  | .ok r => r.body.size ≡ 256
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.ResponseParsing

namespace Tests.ClientConfig

testSuite "Client Configuration"

test "Custom user agent" := do
  let req := Wisp.Request.get "https://httpbin.org/user-agent"
    |>.withUserAgent "CustomAgent/1.0"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => shouldSatisfy (r.bodyTextLossy.containsSubstr "CustomAgent/1.0") "user agent in response"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Gzip encoding" := do
  let result ← awaitTask (client.get "https://httpbin.org/gzip")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "gzipped") "response indicates gzipped"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Deflate encoding" := do
  let result ← awaitTask (client.get "https://httpbin.org/deflate")
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "deflated") "response indicates deflated"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.ClientConfig

namespace Tests.ResponseMetadata

testSuite "Response Metadata"

test "Total time tracked" := do
  let result ← awaitTask (client.get "https://httpbin.org/delay/1")
  match result with
  | .ok r => shouldSatisfy (r.totalTime >= 1.0) "totalTime >= 1.0"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Effective URL tracked" := do
  let result ← awaitTask (client.get "https://httpbin.org/redirect/1")
  match result with
  | .ok r => shouldSatisfy (r.effectiveUrl.containsSubstr "httpbin.org") "effectiveUrl contains httpbin.org"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.ResponseMetadata

namespace Tests.Multipart

testSuite "Multipart Form Uploads"

test "Multipart text field" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "field1", data := "value1".toUTF8 },
    { name := "field2", data := "value2".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "field1") "response contains field1"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "value1") "response contains value1"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Multipart with filename" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "file", filename := some "test.txt", contentType := some "text/plain", data := "file contents here".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "files") "response contains files section"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "file contents here") "response contains file content"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Multipart with content type" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "jsondata", contentType := some "application/json", data := "{\"key\": \"value\"}".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "jsondata") "response contains jsondata"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Multipart

namespace Tests.DigestAuth

testSuite "Digest Authentication"

test "Digest auth (valid)" := do
  let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
    |>.withDigestAuth "testuser" "testpass"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Digest auth (invalid)" := do
  let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
    |>.withDigestAuth "wrong" "credentials"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 401
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.DigestAuth

namespace Tests.ConnectionTimeout

testSuite "Connection Timeout"

test "Connection timeout setting" := do
  let req := Wisp.Request.get "https://httpbin.org/get"
    |>.withConnectTimeout 5000
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.ConnectionTimeout

namespace Tests.SSLOptions

testSuite "SSL Options"

test "SSL verification enabled (default)" := do
  let result ← awaitTask (client.get "https://httpbin.org/get")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "SSL insecure mode" := do
  let req := Wisp.Request.get "https://httpbin.org/get"
    |>.withInsecure
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.SSLOptions

namespace Tests.ResponseHelpers

testSuite "Response Helper Functions"

test "isRedirect for 302" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/1"
    |>.withFollowRedirects false
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => shouldSatisfy r.isRedirect "isRedirect"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "isError for 4xx/5xx" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  match result with
  | .ok r => shouldSatisfy r.isError "isError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "isEmpty for empty body" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/204")
  match result with
  | .ok r => shouldSatisfy r.isEmpty "isEmpty"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "statusText for known codes" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  match result with
  | .ok r => r.statusText ≡ "Not Found"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.ResponseHelpers

namespace Tests.Cookies

testSuite "Cookies"

test "Set-Cookie in response headers" := do
  let result ← awaitTask (client.get "https://httpbin.org/cookies/set/testcookie/testvalue")
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Send cookie via header" := do
  let req := Wisp.Request.get "https://httpbin.org/cookies"
    |>.withHeader "Cookie" "mycookie=myvalue"
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "mycookie") "response contains mycookie"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "myvalue") "response contains myvalue"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Cookies

namespace Tests.MaxRedirects

testSuite "Max Redirects Limit"

test "Max redirects respected" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/5"
    |>.withFollowRedirects true 2
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => shouldSatisfy (r.isRedirect || r.status == 302) "stopped at redirect"
  | .error _ => pure ()  -- Curl error for too many redirects is acceptable

test "Sufficient redirects allowed" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/2"
    |>.withFollowRedirects true 5
  let result ← awaitTask (client.execute req)
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.MaxRedirects

namespace Tests.URLEncoding

testSuite "URL Encoding Edge Cases"

test "Form field with special chars" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("name", "John Doe"),
    ("email", "john+test@example.com"),
    ("query", "a=b&c=d")
  ])
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "John") "response contains John"
    shouldSatisfy (r.bodyTextLossy.containsSubstr "example.com") "response contains example.com"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Form field with unicode" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("greeting", "Héllo Wörld"),
    ("emoji", "👋")
  ])
  match result with
  | .ok r => r.status ≡ 200
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Empty form field" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("empty", ""),
    ("nonempty", "value")
  ])
  match result with
  | .ok r =>
    r.status ≡ 200
    shouldSatisfy (r.bodyTextLossy.containsSubstr "nonempty") "response contains nonempty"
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.URLEncoding

namespace Tests.Streaming

testSuite "Streaming Responses"

test "Stream response body" := do
  let req := Wisp.Request.get "https://httpbin.org/stream-bytes/1000"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let body ← stream.readAllBody
    stream.status ≡ 200
    body.size ≡ 1000
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Stream with forEachChunk" := do
  let req := Wisp.Request.get "https://httpbin.org/stream-bytes/500"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let totalRef ← IO.mkRef (0 : Nat)
    stream.forEachChunk fun chunk => do
      let cur ← totalRef.get
      totalRef.set (cur + chunk.size)
    let total ← totalRef.get
    stream.status ≡ 200
    total ≡ 500
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Streaming status check helpers" := do
  let req := Wisp.Request.get "https://httpbin.org/status/201"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let _ ← stream.readAllBody
    shouldSatisfy stream.isSuccess "isSuccess"
    shouldSatisfy (!stream.isError) "not isError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Streaming 404 response" := do
  let req := Wisp.Request.get "https://httpbin.org/status/404"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let _ ← stream.readAllBody
    stream.status ≡ 404
    shouldSatisfy stream.isClientError "isClientError"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Streaming headers accessible" := do
  let req := Wisp.Request.get "https://httpbin.org/response-headers?X-Custom=streaming-test"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let _ ← stream.readAllBody
    shouldSatisfy (stream.headers.get? "X-Custom").isSome "X-Custom header present"
  | .error e => throw (IO.userError s!"Request failed: {e}")

test "Streaming read body as text" := do
  let req := Wisp.Request.get "https://httpbin.org/json"
  let task ← client.executeStreaming req
  match task.get with
  | .ok stream =>
    let bodyText ← stream.readAllBodyText
    match bodyText with
    | some text => shouldSatisfy (text.containsSubstr "slideshow") "body contains slideshow"
    | none => throw (IO.userError "Expected text body")
  | .error e => throw (IO.userError s!"Request failed: {e}")

#generate_tests

end Tests.Streaming

namespace Tests.SSEParser

testSuite "SSE Parser"

test "Parse basic SSE event" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: hello\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.data ≡ "hello"
    event.event ≡ "message"
  | none => throw (IO.userError "Expected SSE event")

test "Parse SSE event with type" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "event: update\ndata: {\"status\": \"ok\"}\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.event ≡ "update"
    shouldSatisfy (event.data.containsSubstr "status") "data contains status"
  | none => throw (IO.userError "Expected SSE event")

test "Parse SSE event with id" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "id: 123\ndata: test\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.id ≡ some "123"
    event.data ≡ "test"
  | none => throw (IO.userError "Expected SSE event")

test "Parse multiple SSE events" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: first\n\ndata: second\n\ndata: third\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let events ← stream.toArray
  events.size ≡ 3
  events[0]!.data ≡ "first"
  events[1]!.data ≡ "second"
  events[2]!.data ≡ "third"

test "Parse multiline SSE data" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: line1\ndata: line2\ndata: line3\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.data ≡ "line1\nline2\nline3"
  | none => throw (IO.userError "Expected SSE event")

test "Ignore SSE comments" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := ": this is a comment\ndata: actual data\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.data ≡ "actual data"
  | none => throw (IO.userError "Expected SSE event")

test "SSE retry field" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "retry: 5000\ndata: reconnect info\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.retry ≡ some 5000
  | none => throw (IO.userError "Expected SSE event")

test "SSE lastEventId tracking" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "id: evt-001\ndata: first\n\nid: evt-002\ndata: second\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let _ ← stream.recv  -- First event
  let _ ← stream.recv  -- Second event
  let lastId ← stream.getLastEventId
  lastId ≡ some "evt-002"

#generate_tests

end Tests.SSEParser

-- ═══════════════════════════════════════════════════════════════════════════
-- Main
-- ═══════════════════════════════════════════════════════════════════════════

def main : IO UInt32 := do
  IO.println "Wisp Library Tests - Comprehensive Suite"
  IO.println "========================================="
  IO.println ""

  -- Initialize curl
  Wisp.FFI.globalInit

  -- Run all test suites
  let exitCode ← runAllSuites (timeout := 15000)

  IO.println ""
  IO.println "========================================="

  -- Cleanup
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown

  if exitCode > 0 then
    IO.println "Some tests failed!"
    return 1
  else
    IO.println "All tests passed!"
    return 0
