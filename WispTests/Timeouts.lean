import WispTests.Common

open Crucible

namespace WispTests.Timeouts

testSuite "Timeouts"

test "Request completes within timeout" := do
  let req := Wisp.Request.get "https://httpbin.org/delay/1"
    |>.withTimeout 5000
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Timeout test"
  r.status ≡ 200

test "Request times out" := do
  let req := Wisp.Request.get "https://httpbin.org/delay/10"
    |>.withTimeout 1000
  let result ← awaitTask (client.execute req)
  match result with
  | .ok _ => throw (IO.userError "Expected timeout but request succeeded")
  | .error _ => pure ()  -- Timeout is expected



end WispTests.Timeouts
