import WispTests.Common

open Crucible

namespace WispTests.ConnectionTimeout

testSuite "Connection Timeout"

test "Connection timeout setting" := do
  let req := Wisp.Request.get "https://httpbin.org/get"
    |>.withConnectTimeout 5000
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "connection timeout"
  r.status ≡ 200



end WispTests.ConnectionTimeout
