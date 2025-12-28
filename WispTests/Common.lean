/-
  Wisp Tests - Common utilities and imports
-/

import Wisp
import Crucible

open Crucible

/-- Helper to unwrap a successful WispResult or throw on error.
    Wrapper around Crucible's shouldBeOk for Wisp-specific results. -/
def assertOk (result : Wisp.WispResult α) (context : String := "Request") : IO α :=
  shouldBeOk result context

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new
