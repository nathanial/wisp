/-
  Wisp Tests - Common utilities and imports
-/

import Wisp
import Crucible

open Crucible

/-- Check if a string contains a substring -/
def String.containsSubstr (s : String) (sub : String) : Bool :=
  (s.splitOn sub).length > 1

def awaitTask (task : IO (Task α)) : IO α := do
  let t ← task
  return t.get

/-- Helper to unwrap a successful response or throw on error.
    Reduces the repetitive match pattern from 4 lines to 1. -/
def assertOk (result : Wisp.WispResult α) (context : String := "Request") : IO α := do
  match result with
  | .ok r => return r
  | .error e => throw (IO.userError s!"{context} failed: {e}")

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new
