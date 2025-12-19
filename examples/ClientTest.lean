/-
  Client Test
  Tests HTTP Client step by step
-/

import Wisp

def main : IO Unit := do
  IO.println "Client Test"
  IO.println "==========="
  IO.println ""

  IO.println "Step 1: Global init..."
  Wisp.FFI.globalInit
  IO.println "  OK"

  IO.println "Step 2: Creating client..."
  let client := Wisp.HTTP.Client.new
  IO.println s!"  Client: {repr client}"

  IO.println "Step 3: Creating request..."
  let req := Wisp.Request.get "https://httpbin.org/get"
  IO.println "  Request created"

  IO.println "Step 4: Executing request..."
  let task ← client.execute req
  let result := task.get
  IO.println "  Execution complete"

  match result with
  | .ok response =>
    IO.println s!"  Status: {response.status}"
    IO.println s!"  Body size: {response.body.size} bytes"
    IO.println "  [PASS]"
  | .error e =>
    IO.println s!"  Error: {e}"

  IO.println ""
  IO.println "Step 5: Cleanup..."
  Wisp.FFI.globalCleanup
  Wisp.HTTP.Client.shutdown
  IO.println "  OK"

  IO.println ""
  IO.println "Done!"
