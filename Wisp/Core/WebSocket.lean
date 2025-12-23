/-
  Wisp WebSocket Core Types
  WebSocket frame types and basic structures
-/

import Wisp.FFI.Easy

namespace Wisp

/-- WebSocket frame types (based on RFC 6455 opcodes) -/
inductive WebSocketFrameType where
  | continuation  -- Opcode 0x0
  | text          -- Opcode 0x1
  | binary        -- Opcode 0x2
  | close         -- Opcode 0x8
  | ping          -- Opcode 0x9
  | pong          -- Opcode 0xA
  | unknown (code : UInt32)
  deriving Repr, Inhabited, BEq

namespace WebSocketFrameType

/-- Convert from curl frame flags to WebSocketFrameType -/
def fromCurlFlags (flags : UInt32) : WebSocketFrameType :=
  -- Extract the frame type from curl flags (bitmasks from websockets.h)
  -- CURLWS_TEXT = 1 (1<<0), CURLWS_BINARY = 2 (1<<1), CURLWS_CONT = 4 (1<<2),
  -- CURLWS_CLOSE = 8 (1<<3), CURLWS_PING = 16 (1<<4), CURLWS_PONG = 64 (1<<6)
  if flags &&& FFI.CurlWs.TEXT != 0 then .text
  else if flags &&& FFI.CurlWs.BINARY != 0 then .binary
  else if flags &&& FFI.CurlWs.CLOSE != 0 then .close
  else if flags &&& FFI.CurlWs.PING != 0 then .ping
  else if flags &&& FFI.CurlWs.PONG != 0 then .pong
  else if flags == FFI.CurlWs.CONT then .continuation
  else .unknown flags

/-- Convert to curl frame type for sending -/
def toCurlFlags : WebSocketFrameType → UInt32
  | .text => FFI.CurlWs.TEXT
  | .binary => FFI.CurlWs.BINARY
  | .continuation => FFI.CurlWs.CONT
  | .close => FFI.CurlWs.CLOSE
  | .ping => FFI.CurlWs.PING
  | .pong => FFI.CurlWs.PONG
  | .unknown code => code

/-- Check if this is a control frame (close, ping, pong) -/
def isControl : WebSocketFrameType → Bool
  | .close | .ping | .pong => true
  | _ => false

/-- Check if this is a data frame (text, binary, continuation) -/
def isData : WebSocketFrameType → Bool
  | .text | .binary | .continuation => true
  | _ => false

end WebSocketFrameType

/-- A WebSocket frame with its type and payload -/
structure WebSocketFrame where
  /-- The type of frame -/
  frameType : WebSocketFrameType
  /-- The frame payload data -/
  payload : ByteArray
  deriving Inhabited

namespace WebSocketFrame

/-- Create a text frame from a string -/
def text (s : String) : WebSocketFrame :=
  { frameType := .text, payload := s.toUTF8 }

/-- Create a binary frame from raw data -/
def binary (data : ByteArray) : WebSocketFrame :=
  { frameType := .binary, payload := data }

/-- Create a ping frame with optional payload -/
def ping (data : ByteArray := ByteArray.empty) : WebSocketFrame :=
  { frameType := .ping, payload := data }

/-- Create a pong frame with optional payload (usually echoes ping data) -/
def pong (data : ByteArray := ByteArray.empty) : WebSocketFrame :=
  { frameType := .pong, payload := data }

/-- Create a close frame with optional status code and reason -/
def close (code : UInt16 := 1000) (reason : String := "") : WebSocketFrame :=
  let codeBytes : ByteArray := ByteArray.mk #[(code >>> 8).toUInt8, code.toUInt8]
  let payload := if reason.isEmpty then codeBytes else codeBytes ++ reason.toUTF8
  { frameType := .close, payload := payload }

/-- Get payload as a UTF-8 string (for text frames) -/
def payloadText (f : WebSocketFrame) : Option String :=
  String.fromUTF8? f.payload

/-- Get payload as lossy UTF-8 string -/
def payloadTextLossy (f : WebSocketFrame) : String :=
  String.fromUTF8! f.payload

/-- Check if this is a text frame -/
def isText (f : WebSocketFrame) : Bool :=
  f.frameType == .text

/-- Check if this is a binary frame -/
def isBinary (f : WebSocketFrame) : Bool :=
  f.frameType == .binary

/-- Check if this is a close frame -/
def isClose (f : WebSocketFrame) : Bool :=
  f.frameType == .close

/-- Check if this is a ping frame -/
def isPing (f : WebSocketFrame) : Bool :=
  f.frameType == .ping

/-- Check if this is a pong frame -/
def isPong (f : WebSocketFrame) : Bool :=
  f.frameType == .pong

/-- Parse close code from a close frame -/
def closeCode (f : WebSocketFrame) : Option UInt16 :=
  if f.frameType != .close || f.payload.size < 2 then none
  else
    let high := f.payload[0]!.toUInt16
    let low := f.payload[1]!.toUInt16
    some ((high <<< 8) ||| low)

/-- Parse close reason from a close frame -/
def closeReason (f : WebSocketFrame) : Option String :=
  if f.frameType != .close || f.payload.size <= 2 then none
  else String.fromUTF8? (f.payload.extract 2 f.payload.size)

end WebSocketFrame

-- WebSocket close codes (RFC 6455)
namespace WebSocketCloseCode

def normal : UInt16 := 1000
def goingAway : UInt16 := 1001
def protocolError : UInt16 := 1002
def unsupportedData : UInt16 := 1003
def noStatusReceived : UInt16 := 1005
def abnormalClosure : UInt16 := 1006
def invalidPayload : UInt16 := 1007
def policyViolation : UInt16 := 1008
def messageTooLarge : UInt16 := 1009
def mandatoryExtension : UInt16 := 1010
def internalError : UInt16 := 1011
def tlsHandshakeFailed : UInt16 := 1015

end WebSocketCloseCode

end Wisp
