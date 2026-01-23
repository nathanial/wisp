import WispTests.Common

open Crucible

namespace WispTests.RequestBodies

testSuite "Request Body Types"

test "JSON body" := do
  let result ← awaitTask (client.postJson "https://httpbin.org/post" "{\"key\": \"value\"}")
  let r ← shouldBeOk result "JSON POST"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "application/json") "response contains application/json"

test "Form-encoded body" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[("field1", "value1"), ("field2", "value2")])
  let r ← shouldBeOk result "Form POST"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "field1") "response contains field1"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "value1") "response contains value1"

test "Plain text body" := do
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withText "Hello, World!"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Text POST"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "Hello, World!") "response contains Hello, World!"

test "Raw bytes body" := do
  let bytes := "raw data".toUTF8
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withBody bytes "application/octet-stream"
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "Raw POST"
  r.status ≡ 200



end WispTests.RequestBodies
