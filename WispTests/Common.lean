/-
  Wisp Tests - Common utilities and imports
-/

import Wisp
import Crucible
import Staple

open Crucible
export Staple (String.containsSubstr)

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new
