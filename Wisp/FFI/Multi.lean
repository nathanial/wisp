/-
  Wisp FFI Multi Handle
  Low-level bindings to curl_multi_* functions for concurrent requests
-/

import Wisp.FFI.Easy

namespace Wisp.FFI

-- ============================================================================
-- Opaque Types
-- ============================================================================

/-- Opaque handle to a curl multi handle for concurrent requests -/
opaque MultiPointed : NonemptyType
def Multi := MultiPointed.type
instance : Nonempty Multi := MultiPointed.property

-- ============================================================================
-- Multi Handle Operations
-- ============================================================================

/-- Create a new curl multi handle. -/
@[extern "wisp_multi_init"]
opaque multiInit : IO Multi

/-- Cleanup a multi handle. Usually not needed due to automatic finalization. -/
@[extern "wisp_multi_cleanup"]
opaque multiCleanup (multi : @& Multi) : IO Unit

/-- Add an easy handle to the multi stack. -/
@[extern "wisp_multi_add_handle"]
opaque multiAddHandle (multi : @& Multi) (easy : @& Easy) : IO Unit

/-- Remove an easy handle from the multi stack. -/
@[extern "wisp_multi_remove_handle"]
opaque multiRemoveHandle (multi : @& Multi) (easy : @& Easy) : IO Unit

/-- Perform transfers on all added handles. Returns number still running. -/
@[extern "wisp_multi_perform"]
opaque multiPerform (multi : @& Multi) : IO UInt32

/-- Wait for activity on any handle. Returns number of handles with activity. -/
@[extern "wisp_multi_poll"]
opaque multiPoll (multi : @& Multi) (timeoutMs : UInt32) : IO UInt32

/-- Read a completed transfer (id, curl code), if any. -/
@[extern "wisp_multi_info_read"]
opaque multiInfoRead (multi : @& Multi) : IO (Option (UInt64 × UInt32))

end Wisp.FFI
