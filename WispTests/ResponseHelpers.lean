import WispTests.Common

open Crucible

namespace WispTests.ResponseHelpers

testSuite "Response Helper Functions"

test "isRedirect for 302" := do
  let req := Wisp.Request.get "https://httpbin.org/redirect/1"
    |>.withFollowRedirects false
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "redirect check"
  shouldSatisfy r.isRedirect "isRedirect"

test "isError for 4xx/5xx" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  let r ← shouldBeOk result "404 check"
  shouldSatisfy r.isError "isError"

test "isEmpty for empty body" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/204")
  let r ← shouldBeOk result "204 check"
  shouldSatisfy r.isEmpty "isEmpty"

test "statusText for known codes" := do
  let result ← awaitTask (client.get "https://httpbin.org/status/404")
  let r ← shouldBeOk result "statusText check"
  r.statusText ≡ "Not Found"



end WispTests.ResponseHelpers
