import WispTests.Common

open Crucible

namespace WispTests.HTTPMethods

testSuite "HTTP Methods"

-- Fixture hooks demonstration
beforeAll := do
  IO.println "  [HTTP Methods: Starting test suite]"

afterAll := do
  IO.println "  [HTTP Methods: Suite complete]"

test "GET request" := do
  let result ← awaitTask (client.get "https://httpbin.org/get")
  let r ← assertOk result "GET"
  r.status ≡ 200

test "POST request" := do
  let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"test\": 1}")
  let r ← assertOk result "POST"
  r.status ≡ 200

test "PUT request" := do
  let result ← awaitTask (client.putJson "https://httpbin.org/put" "{\"update\": true}")
  let r ← assertOk result "PUT"
  r.status ≡ 200

test "DELETE request" := do
  let result ← awaitTask (client.delete "https://httpbin.org/delete")
  let r ← assertOk result "DELETE"
  r.status ≡ 200

test "HEAD request" := do
  let result ← awaitTask (client.head "https://httpbin.org/get")
  let r ← assertOk result "HEAD"
  r.status ≡ 200
  shouldSatisfy r.body.isEmpty "HEAD response body is empty"

test "PATCH request" := do
  let req := Wisp.Request.patch "https://httpbin.org/patch" |>.withJson "{\"patch\": true}"
  let result ← awaitTask (client.execute req)
  let r ← assertOk result "PATCH"
  r.status ≡ 200

test "OPTIONS request" := do
  let req := Wisp.Request.options "https://httpbin.org/get"
  let result ← awaitTask (client.execute req)
  let r ← assertOk result "OPTIONS"
  r.status ≡ 200

#generate_tests

end WispTests.HTTPMethods
