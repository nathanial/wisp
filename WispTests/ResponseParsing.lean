import WispTests.Common

open Crucible

namespace WispTests.ResponseParsing

testSuite "Response Body Parsing"

test "Body as text (valid UTF-8)" := do
  let result ← awaitTask (client.get "https://httpbin.org/encoding/utf8")
  let r ← assertOk result "UTF-8 body"
  match r.bodyText with
  | some text => shouldSatisfy (text.length > 0) "body has content"
  | none => throw (IO.userError "Expected valid UTF-8 body")

test "Body as lossy text" := do
  let result ← awaitTask (client.get "https://httpbin.org/bytes/100")
  let r ← assertOk result "Lossy text"
  shouldSatisfy (r.bodyTextLossy.length > 0) "lossy text has content"

test "Body size tracking" := do
  let result ← awaitTask (client.get "https://httpbin.org/bytes/256")
  let r ← assertOk result "Body size"
  r.body.size ≡ 256

#generate_tests

end WispTests.ResponseParsing
