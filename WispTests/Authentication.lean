import WispTests.Common

open Crucible

namespace WispTests.Authentication

testSuite "Authentication"

test "Basic auth (valid)" := do
  let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
    |>.withBasicAuth "testuser" "testpass"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Basic auth"
  r.status ≡ 200

test "Basic auth (invalid)" := do
  let req := Wisp.Request.get "https://httpbin.org/basic-auth/testuser/testpass"
    |>.withBasicAuth "wrong" "credentials"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Basic auth invalid"
  r.status ≡ 401

test "Bearer token" := do
  let req := Wisp.Request.get "https://httpbin.org/bearer"
    |>.withBearerToken "my-secret-token"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Bearer token"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "my-secret-token") "response contains token"



end WispTests.Authentication
