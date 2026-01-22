/-
  Wisp Test Runner - Comprehensive Test Suite
  Using Crucible Test Framework
-/

import WispTests.Common
import WispTests.BasicFFI
import WispTests.HTTPMethods
import WispTests.RequestBodies
import WispTests.Headers
import WispTests.Authentication
import WispTests.Redirects
import WispTests.Timeouts
import WispTests.StatusCodes
import WispTests.ResponseParsing
import WispTests.ClientConfig
import WispTests.ResponseMetadata
import WispTests.Multipart
import WispTests.DigestAuth
import WispTests.ConnectionTimeout
import WispTests.SSLOptions
import WispTests.ResponseHelpers
import WispTests.Cookies
import WispTests.MaxRedirects
import WispTests.URLEncoding
import WispTests.Streaming
import WispTests.SSEParser
import WispTests.WebSocket

open Crucible

/-!
Note: Global curl initialization is done in main rather than via fixtures because:
1. It's truly process-global (not per-suite) - libcurl requires one init/cleanup per process
2. Fixtures are per-suite, so we'd need to coordinate across 22 suites
3. The cleanup must happen after ALL suites complete, not after each suite

Individual suites can still use beforeAll/afterAll for suite-specific setup.
See WispTests.HTTPMethods for an example of fixture usage.
-/

def main : IO UInt32 := do
  IO.println "Wisp Library Tests - Comprehensive Suite"
  IO.println "========================================="
  IO.println ""

  -- Initialize curl (process-global, must happen before any HTTP calls)
  Wisp.FFI.globalInit

  -- Run all test suites
  let exitCode ← runAllSuites (timeout := 15000) (retry := 3)

  IO.println ""
  IO.println "========================================="

  -- Cleanup (process-global, must happen after all suites complete)
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown

  if exitCode > 0 then
    IO.println "Some tests failed!"
    return 1
  else
    IO.println "All tests passed!"
    return 0
