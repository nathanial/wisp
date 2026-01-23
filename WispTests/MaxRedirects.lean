import WispTests.Common

open Crucible

namespace WispTests.MaxRedirects

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
  let r ← shouldBeOk result "sufficient redirects"
  r.status ≡ 200



end WispTests.MaxRedirects
