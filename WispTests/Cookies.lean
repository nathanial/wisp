import WispTests.Common

open Crucible

namespace WispTests.Cookies

testSuite "Cookies"

test "Set-Cookie in response headers" := do
  let result ← awaitTask (client.get "https://httpbin.org/cookies/set/testcookie/testvalue")
  let r ← shouldBeOk result "set cookie"
  r.status ≡ 200

test "Send cookie via header" := do
  let req := Wisp.Request.get "https://httpbin.org/cookies"
    |>.withHeader "Cookie" "mycookie=myvalue"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "send cookie"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "mycookie") "response contains mycookie"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "myvalue") "response contains myvalue"

test "Cookie jar with in-memory engine" := do
  -- httpbin.org/cookies/set sets a cookie and redirects to /cookies
  -- With cookie engine enabled, the cookie persists across the redirect
  let req := Wisp.Request.get "https://httpbin.org/cookies/set/jartest/jarvalue"
    |>.withCookieEngine
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "cookie jar"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "jartest") "response contains jartest cookie"

test "Inline cookie string with withCookies" := do
  let req := Wisp.Request.get "https://httpbin.org/cookies"
    |>.withCookies "inlinecookie=inlinevalue"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "inline cookies"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "inlinecookie") "response contains inlinecookie"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "inlinevalue") "response contains inlinevalue"



end WispTests.Cookies
