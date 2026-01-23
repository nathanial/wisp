import WispTests.Common

open Crucible

namespace WispTests.DigestAuth

testSuite "Digest Authentication"

test "Digest auth (valid)" := do
  let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
    |>.withDigestAuth "testuser" "testpass"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "digest auth"
  r.status ≡ 200

test "Digest auth (invalid)" := do
  let req := Wisp.Request.get "https://httpbin.org/digest-auth/auth/testuser/testpass"
    |>.withDigestAuth "wrong" "credentials"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "digest auth invalid"
  r.status ≡ 401



end WispTests.DigestAuth
