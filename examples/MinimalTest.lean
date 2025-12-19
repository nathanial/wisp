/-
  Minimal FFI Test
  Tests basic FFI functionality without HTTP requests
-/

import Wisp

def main : IO Unit := do
  IO.println "Minimal FFI Test"
  IO.println "================"
  IO.println ""

  IO.println "Step 1: Global init..."
  Wisp.FFI.globalInit
  IO.println "  OK"

  IO.println "Step 2: Version info..."
  let version ← Wisp.FFI.versionInfo
  IO.println s!"  {version}"

  IO.println "Step 3: Creating easy handle..."
  let easy ← Wisp.FFI.easyInit
  IO.println "  OK"

  IO.println "Step 4: Setting up callbacks..."
  Wisp.FFI.setupWriteCallback easy
  Wisp.FFI.setupHeaderCallback easy
  IO.println "  OK"

  IO.println "Step 5: Setting URL..."
  Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.URL "https://httpbin.org/get"
  IO.println "  OK"

  IO.println "Step 6: Performing request..."
  Wisp.FFI.easyPerform easy
  IO.println "  OK"

  IO.println "Step 7: Getting response code..."
  let status ← Wisp.FFI.getinfoLong easy Wisp.FFI.CurlInfo.RESPONSE_CODE
  IO.println s!"  Status: {status}"

  IO.println "Step 8: Getting response body..."
  let body ← Wisp.FFI.getResponseBody easy
  IO.println s!"  Body size: {body.size} bytes"

  IO.println "Step 9: Cleanup..."
  Wisp.FFI.globalCleanup
  IO.println "  OK"

  IO.println ""
  IO.println "All steps passed!"
