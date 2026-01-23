import WispTests.Common

open Crucible

namespace WispTests.SSLOptions

testSuite "SSL Options"

test "SSL verification enabled (default)" := do
  let result ← awaitTask (client.get "https://httpbin.org/get")
  let r ← shouldBeOk result "SSL GET"
  r.status ≡ 200

test "SSL insecure mode" := do
  let req := Wisp.Request.get "https://httpbin.org/get"
    |>.withInsecure
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "SSL insecure"
  r.status ≡ 200



end WispTests.SSLOptions
