import WispTests.Common

open Crucible

namespace WispTests.ClientConfig

testSuite "Client Configuration"

test "Custom user agent" := do
  let req := Wisp.Request.get "https://httpbin.org/user-agent"
    |>.withUserAgent "CustomAgent/1.0"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "User agent"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "CustomAgent/1.0") "user agent in response"

test "Gzip encoding" := do
  let result ← awaitTask (client.get "https://httpbin.org/gzip")
  let r ← shouldBeOk result "Gzip"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "gzipped") "response indicates gzipped"

test "Deflate encoding" := do
  let result ← awaitTask (client.get "https://httpbin.org/deflate")
  let r ← shouldBeOk result "Deflate"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "deflated") "response indicates deflated"



end WispTests.ClientConfig
