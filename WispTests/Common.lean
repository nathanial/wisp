/-
  Wisp Tests - Common utilities and imports
-/

import Wisp
import Crucible

open Crucible

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new
