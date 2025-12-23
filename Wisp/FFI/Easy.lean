/-
  Wisp FFI Easy Handle
  Low-level bindings to curl_easy_* functions
-/

namespace Wisp.FFI

-- ============================================================================
-- Opaque Types
-- ============================================================================

/-- Opaque handle to a curl easy handle -/
opaque EasyPointed : NonemptyType
def Easy := EasyPointed.type
instance : Nonempty Easy := EasyPointed.property

/-- Opaque handle to a curl slist (header list) -/
opaque SlistPointed : NonemptyType
def Slist := SlistPointed.type
instance : Nonempty Slist := SlistPointed.property

/-- Opaque handle to a curl mime handle (multipart form) -/
opaque MimePointed : NonemptyType
def Mime := MimePointed.type
instance : Nonempty Mime := MimePointed.property

/-- Opaque handle to a curl mime part -/
opaque MimepartPointed : NonemptyType
def Mimepart := MimepartPointed.type
instance : Nonempty Mimepart := MimepartPointed.property

-- ============================================================================
-- Curl Option Constants (CURLOPT_*)
-- ============================================================================

namespace CurlOpt
  -- Behavior options
  def VERBOSE : UInt32 := 41
  def HEADER : UInt32 := 42
  def NOPROGRESS : UInt32 := 43
  def NOBODY : UInt32 := 44
  def FAILONERROR : UInt32 := 45
  def UPLOAD : UInt32 := 46
  def POST : UInt32 := 47
  def FOLLOWLOCATION : UInt32 := 52

  -- Network options
  def URL : UInt32 := 10002
  def PORT : UInt32 := 3
  def PROXY : UInt32 := 10004
  def USERPWD : UInt32 := 10005
  def PROXYUSERPWD : UInt32 := 10006
  def RANGE : UInt32 := 10007
  def TIMEOUT : UInt32 := 13
  def TIMEOUT_MS : UInt32 := 155
  def CONNECTTIMEOUT : UInt32 := 78
  def CONNECTTIMEOUT_MS : UInt32 := 156

  -- HTTP options
  def HTTPGET : UInt32 := 80
  def HTTPHEADER : UInt32 := 10023
  def POSTFIELDS : UInt32 := 10015
  def COPYPOSTFIELDS : UInt32 := 10165
  def POSTFIELDSIZE : UInt32 := 60
  def POSTFIELDSIZE_LARGE : UInt32 := 30120
  def CUSTOMREQUEST : UInt32 := 10036
  def REFERER : UInt32 := 10016
  def USERAGENT : UInt32 := 10018
  def COOKIE : UInt32 := 10022
  def COOKIEFILE : UInt32 := 10031
  def COOKIEJAR : UInt32 := 10082
  def HTTPAUTH : UInt32 := 107
  def ACCEPT_ENCODING : UInt32 := 10102
  def MAXREDIRS : UInt32 := 68

  -- SSL/TLS options
  def SSL_VERIFYPEER : UInt32 := 64
  def SSL_VERIFYHOST : UInt32 := 81
  def CAINFO : UInt32 := 10065
  def CAPATH : UInt32 := 10097
  def SSLCERT : UInt32 := 10025
  def SSLKEY : UInt32 := 10087
  def SSLCERTTYPE : UInt32 := 10086
  def SSLKEYTYPE : UInt32 := 10088

  -- MIME/multipart
  def MIMEPOST : UInt32 := 10269

  -- Auth types for HTTPAUTH
  def AUTH_BASIC : Int64 := 1
  def AUTH_DIGEST : Int64 := 2
  def AUTH_BEARER : Int64 := 64

  -- WebSocket options (curl 7.86+)
  def CONNECT_ONLY : UInt32 := 141
  def WS_OPTIONS : UInt32 := 320
end CurlOpt

-- WebSocket frame type constants (curl 7.86+)
-- These are bitmask flags from websockets.h
namespace CurlWs
  def TEXT : UInt32 := 1      -- 1<<0
  def BINARY : UInt32 := 2    -- 1<<1
  def CONT : UInt32 := 4      -- 1<<2
  def CLOSE : UInt32 := 8     -- 1<<3
  def PING : UInt32 := 16     -- 1<<4
  def PONG : UInt32 := 64     -- 1<<6
end CurlWs

-- ============================================================================
-- Curl Info Constants (CURLINFO_*)
-- ============================================================================

namespace CurlInfo
  -- String info
  def EFFECTIVE_URL : UInt32 := 0x100001
  def CONTENT_TYPE : UInt32 := 0x100012
  def REDIRECT_URL : UInt32 := 0x100013
  def PRIMARY_IP : UInt32 := 0x100014

  -- Long info
  def RESPONSE_CODE : UInt32 := 0x200002
  def HEADER_SIZE : UInt32 := 0x20000B
  def REQUEST_SIZE : UInt32 := 0x20000C
  def SSL_VERIFYRESULT : UInt32 := 0x20000D
  def FILETIME : UInt32 := 0x20000E
  def REDIRECT_COUNT : UInt32 := 0x200014
  def HTTP_CONNECTCODE : UInt32 := 0x200016
  def HTTPAUTH_AVAIL : UInt32 := 0x200017
  def OS_ERRNO : UInt32 := 0x200019
  def NUM_CONNECTS : UInt32 := 0x20001A
  def PRIMARY_PORT : UInt32 := 0x200021
  def LOCAL_PORT : UInt32 := 0x200022

  -- Double info
  def TOTAL_TIME : UInt32 := 0x300003
  def NAMELOOKUP_TIME : UInt32 := 0x300004
  def CONNECT_TIME : UInt32 := 0x300005
  def PRETRANSFER_TIME : UInt32 := 0x300006
  def SIZE_UPLOAD : UInt32 := 0x300007
  def SIZE_DOWNLOAD : UInt32 := 0x300008
  def SPEED_DOWNLOAD : UInt32 := 0x300009
  def SPEED_UPLOAD : UInt32 := 0x30000A
  def STARTTRANSFER_TIME : UInt32 := 0x300011
  def REDIRECT_TIME : UInt32 := 0x300013
end CurlInfo

-- ============================================================================
-- Initialization
-- ============================================================================

/-- Initialize libcurl globally. Called automatically on first use. -/
@[extern "wisp_global_init"]
opaque globalInit : IO Unit

/-- Cleanup libcurl globally. Call at application shutdown. -/
@[extern "wisp_global_cleanup"]
opaque globalCleanup : IO Unit

/-- Get libcurl version information. -/
@[extern "wisp_version_info"]
opaque versionInfo : IO String

-- ============================================================================
-- Easy Handle Operations
-- ============================================================================

/-- Create a new curl easy handle. -/
@[extern "wisp_easy_init"]
opaque easyInit : IO Easy

/-- Cleanup an easy handle. Usually not needed due to automatic finalization. -/
@[extern "wisp_easy_cleanup"]
opaque easyCleanup (easy : @& Easy) : IO Unit

/-- Reset an easy handle to initial state. -/
@[extern "wisp_easy_reset"]
opaque easyReset (easy : @& Easy) : IO Unit

/-- Perform the transfer configured on this handle. -/
@[extern "wisp_easy_perform"]
opaque easyPerform (easy : @& Easy) : IO Unit

-- ============================================================================
-- Setopt Operations
-- ============================================================================

/-- Set a string option. -/
@[extern "wisp_easy_setopt_string"]
opaque setoptString (easy : @& Easy) (option : UInt32) (value : @& String) : IO Unit

/-- Set a long/integer option. -/
@[extern "wisp_easy_setopt_long"]
opaque setoptLong (easy : @& Easy) (option : UInt32) (value : Int64) : IO Unit

/-- Set a private pointer value (CURLOPT_PRIVATE). -/
@[extern "wisp_easy_setopt_private"]
opaque setoptPrivate (easy : @& Easy) (value : UInt64) : IO Unit

/-- Set an slist (header list) option. -/
@[extern "wisp_easy_setopt_slist"]
opaque setoptSlist (easy : @& Easy) (option : UInt32) (slist : @& Slist) : IO Unit

/-- Set a mime (multipart form) option. -/
@[extern "wisp_easy_setopt_mime"]
opaque setoptMime (easy : @& Easy) (mime : @& Mime) : IO Unit

-- ============================================================================
-- Getinfo Operations
-- ============================================================================

/-- Get a long/integer info value. -/
@[extern "wisp_easy_getinfo_long"]
opaque getinfoLong (easy : @& Easy) (info : UInt32) : IO UInt64

/-- Get a double/float info value. -/
@[extern "wisp_easy_getinfo_double"]
opaque getinfoDouble (easy : @& Easy) (info : UInt32) : IO Float

/-- Get a string info value. -/
@[extern "wisp_easy_getinfo_string"]
opaque getinfoString (easy : @& Easy) (info : UInt32) : IO String

-- ============================================================================
-- Response Buffer Operations
-- ============================================================================

/-- Setup write callback to capture response body. -/
@[extern "wisp_easy_setup_write_callback"]
opaque setupWriteCallback (easy : @& Easy) : IO Unit

/-- Setup header callback to capture response headers. -/
@[extern "wisp_easy_setup_header_callback"]
opaque setupHeaderCallback (easy : @& Easy) : IO Unit

/-- Get the response body as a ByteArray. Call after easyPerform. -/
@[extern "wisp_easy_get_response_body"]
opaque getResponseBody (easy : @& Easy) : IO ByteArray

/-- Get the response headers as a raw String. Call after easyPerform. -/
@[extern "wisp_easy_get_response_headers"]
opaque getResponseHeaders (easy : @& Easy) : IO String

-- ============================================================================
-- Slist Operations
-- ============================================================================

/-- Create a new empty slist. -/
@[extern "wisp_slist_new"]
opaque slistNew : IO Slist

/-- Append a string to the slist. -/
@[extern "wisp_slist_append"]
opaque slistAppend (slist : @& Slist) (str : @& String) : IO Unit

/-- Free an slist. Usually not needed due to automatic finalization. -/
@[extern "wisp_slist_free"]
opaque slistFree (slist : @& Slist) : IO Unit

-- ============================================================================
-- Mime Operations (Multipart Form Data)
-- ============================================================================

/-- Create a new mime handle for multipart form data. -/
@[extern "wisp_mime_init"]
opaque mimeInit (easy : @& Easy) : IO Mime

/-- Add a new part to the mime handle. -/
@[extern "wisp_mime_addpart"]
opaque mimeAddpart (mime : @& Mime) : IO Mimepart

/-- Set the name (field name) of a mime part. -/
@[extern "wisp_mimepart_name"]
opaque mimepartName (part : @& Mimepart) (name : @& String) : IO Unit

/-- Set the data of a mime part from a ByteArray. -/
@[extern "wisp_mimepart_data"]
opaque mimepartData (part : @& Mimepart) (data : @& ByteArray) : IO Unit

/-- Set the filename of a mime part (for file uploads). -/
@[extern "wisp_mimepart_filename"]
opaque mimepartFilename (part : @& Mimepart) (filename : @& String) : IO Unit

/-- Set the content type of a mime part. -/
@[extern "wisp_mimepart_type"]
opaque mimepartType (part : @& Mimepart) (mimetype : @& String) : IO Unit

/-- Set the data of a mime part from a file path. -/
@[extern "wisp_mimepart_filedata"]
opaque mimepartFiledata (part : @& Mimepart) (filepath : @& String) : IO Unit

/-- Free a mime handle. Usually not needed due to automatic finalization. -/
@[extern "wisp_mime_free"]
opaque mimeFree (mime : @& Mime) : IO Unit

-- ============================================================================
-- URL Encoding
-- ============================================================================

/-- URL-encode a string. -/
@[extern "wisp_url_encode"]
opaque urlEncode (easy : @& Easy) (str : @& String) : IO String

/-- URL-decode a string. -/
@[extern "wisp_url_decode"]
opaque urlDecode (easy : @& Easy) (str : @& String) : IO String

-- ============================================================================
-- Streaming Support
-- ============================================================================

/-- Enable or disable streaming mode for this handle. -/
@[extern "wisp_easy_set_streaming"]
opaque setStreaming (easy : @& Easy) (streaming : Bool) : IO Unit

/-- Check if streaming mode is enabled. -/
@[extern "wisp_easy_is_streaming"]
opaque isStreaming (easy : @& Easy) : IO Bool

/-- Check if all headers have been received. -/
@[extern "wisp_easy_headers_complete"]
opaque headersComplete (easy : @& Easy) : IO Bool

/-- Drain any new body data since last call. Returns empty if no new data. -/
@[extern "wisp_easy_drain_body_chunk"]
opaque drainBodyChunk (easy : @& Easy) : IO ByteArray

/-- Check if there's pending body data to drain. -/
@[extern "wisp_easy_has_pending_data"]
opaque hasPendingData (easy : @& Easy) : IO Bool

/-- Reset streaming state (read offset, headers_complete flag). -/
@[extern "wisp_easy_reset_streaming"]
opaque resetStreaming (easy : @& Easy) : IO Unit

-- ============================================================================
-- WebSocket Support (curl 7.86+)
-- ============================================================================

/-- Check if WebSocket support is available in the linked libcurl. -/
@[extern "wisp_ws_check_support"]
opaque wsCheckSupport : IO Bool

/-- Send a WebSocket frame. frameType should be one of CurlWs constants. -/
@[extern "wisp_ws_send"]
opaque wsSend (easy : @& Easy) (data : @& ByteArray) (frameType : UInt32) : IO Unit

/-- Receive a WebSocket frame. Returns None if no data available (non-blocking).
    Returns (payload, frameType) on success. -/
@[extern "wisp_ws_recv"]
opaque wsRecv (easy : @& Easy) : IO (Option (ByteArray × UInt32))

/-- Get WebSocket metadata (offset, bytesleft, flags) after a recv call. -/
@[extern "wisp_ws_meta"]
opaque wsMeta (easy : @& Easy) : IO (UInt64 × UInt64 × UInt32)

end Wisp.FFI
