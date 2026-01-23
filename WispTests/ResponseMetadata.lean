import WispTests.Common

open Crucible

namespace WispTests.ResponseMetadata

testSuite "Response Metadata"

test "Total time tracked" := do
  let result ← awaitTask (client.get "https://httpbin.org/delay/1")
  let r ← shouldBeOk result "GET delay"
  shouldSatisfy (r.totalTime >= 1.0) "totalTime >= 1.0"

test "Effective URL tracked" := do
  let result ← awaitTask (client.get "https://httpbin.org/redirect/1")
  let r ← shouldBeOk result "GET redirect"
  shouldSatisfy (r.effectiveUrl.containsSubstr "httpbin.org") "effectiveUrl contains httpbin.org"



end WispTests.ResponseMetadata
