/-
  Wisp Tests - Common utilities and imports
-/

import Wisp
import Crucible
import Staple

open Crucible
export Staple (String.containsSubstr)

def defaultTimeoutMs : UInt64 := 10000
def defaultConnectTimeoutMs : UInt64 := 5000

-- Client is created at module level (pure operation)
def client := Wisp.HTTP.Client.new
  |>.withTimeout defaultTimeoutMs
  |>.withConnectTimeout defaultConnectTimeoutMs
