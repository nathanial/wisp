import WispTests.Common

open Crucible

namespace WispTests.BasicFFI

testSuite "Basic FFI"

test "Version info" := do
  let version ← Wisp.FFI.versionInfo
  shouldSatisfy (version.containsSubstr "libcurl") "version contains libcurl"



end WispTests.BasicFFI
