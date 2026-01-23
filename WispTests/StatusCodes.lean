import WispTests.Common

open Crucible

namespace WispTests.StatusCodes

testSuite "HTTP Status Codes"

test "200 OK" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/200")
  let r ← shouldBeOk result "200 OK"
  r.status ≡ 200
  shouldSatisfy r.isSuccess "isSuccess"

test "201 Created" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/201")
  let r ← shouldBeOk result "201 Created"
  r.status ≡ 201
  shouldSatisfy r.isSuccess "isSuccess"

test "204 No Content" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/204")
  let r ← shouldBeOk result "204 No Content"
  r.status ≡ 204
  shouldSatisfy r.isSuccess "isSuccess"

test "400 Bad Request" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/400")
  let r ← shouldBeOk result "400 Bad Request"
  r.status ≡ 400
  shouldSatisfy r.isClientError "isClientError"

test "401 Unauthorized" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/401")
  let r ← shouldBeOk result "401 Unauthorized"
  r.status ≡ 401
  shouldSatisfy r.isClientError "isClientError"

test "403 Forbidden" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/403")
  let r ← shouldBeOk result "403 Forbidden"
  r.status ≡ 403
  shouldSatisfy r.isClientError "isClientError"

test "404 Not Found" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  let r ← shouldBeOk result "404 Not Found"
  r.status ≡ 404
  shouldSatisfy r.isClientError "isClientError"

test "500 Internal Server Error" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/500")
  let r ← shouldBeOk result "500 Server Error"
  r.status ≡ 500
  shouldSatisfy r.isServerError "isServerError"

test "502 Bad Gateway" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/502")
  let r ← shouldBeOk result "502 Bad Gateway"
  r.status ≡ 502
  shouldSatisfy r.isServerError "isServerError"

test "503 Service Unavailable" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/503")
  let r ← shouldBeOk result "503 Unavailable"
  r.status ≡ 503
  shouldSatisfy r.isServerError "isServerError"



end WispTests.StatusCodes
