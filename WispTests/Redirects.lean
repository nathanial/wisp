import WispTests.Common

open Crucible

namespace WispTests.Redirects

testSuite "Redirects"

test "Follow redirects (default)" := do
  let result ← awaitTask (client.get "https://httpbin.org/redirect/2")
  let r ← shouldBeOk result "Follow redirects"
  r.status ≡ 200
  shouldSatisfy (r.effectiveUrl.containsSubstr "/get") "redirected to /get"

test "Don't follow redirects" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/1"
    |>.withFollowRedirects false
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "No follow redirects"
  r.status ≡ 302

test "Absolute redirect" := do
  let result ← awaitTask (client.get "https://httpbin.org/absolute-redirect/1")
  let r ← shouldBeOk result "Absolute redirect"
  r.status ≡ 200



end WispTests.Redirects
