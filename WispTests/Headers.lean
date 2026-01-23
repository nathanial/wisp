import WispTests.Common

open Crucible

namespace WispTests.Headers

testSuite "Headers"

test "Custom headers sent" := do
  let req := Wisp.Request.get "https://httpbin.org/headers"
    |>.withHeader "X-Test-Header" "test-value-123"
    |>.withHeader "X-Another" "another-value"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Headers GET"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "X-Test-Header") "response contains X-Test-Header"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "test-value-123") "response contains test-value-123"

test "Response headers parsed" := do
  let result ← awaitTask (client.get "https://httpbin.org/response-headers?X-Custom-Response=hello")
  let r ← shouldBeOk result "Response headers"
  shouldSatisfy (r.headers.get? "X-Custom-Response").isSome "X-Custom-Response header present"

test "Content-Type header" := do
  let result ← awaitTask (client.get "https://httpbin.org/json")
  let r ← shouldBeOk result "Content-Type"
  shouldSatisfy r.contentType.isSome "Content-Type header present"
  shouldSatisfy ((r.contentType.getD "").containsSubstr "json") "Content-Type contains json"



end WispTests.Headers
