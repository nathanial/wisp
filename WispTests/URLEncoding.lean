import WispTests.Common

open Crucible

namespace WispTests.URLEncoding

testSuite "URL Encoding Edge Cases"

test "Form field with special chars" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("name", "John Doe"),
    ("email", "john+test@example.com"),
    ("query", "a=b&c=d")
  ])
  let r ← shouldBeOk result "form special chars"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "John") "response contains John"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "example.com") "response contains example.com"

test "Form field with unicode" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("greeting", "Héllo Wörld"),
    ("emoji", "👋")
  ])
  let r ← shouldBeOk result "form unicode"
  r.status ≡ 200

test "Empty form field" := do
  let result ← awaitTask (client.postForm "https://httpbin.org/post" #[
    ("empty", ""),
    ("nonempty", "value")
  ])
  let r ← shouldBeOk result "form empty field"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "nonempty") "response contains nonempty"



end WispTests.URLEncoding
