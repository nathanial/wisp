/-
  Wisp WebSocket Client
  High-level WebSocket connection API using libcurl
-/

import Wisp.Core.Types
import Wisp.Core.Error
import Wisp.Core.WebSocket
import Wisp.FFI.Easy

namespace Wisp.WebSocket

/-- Check if WebSocket support is available in the linked libcurl -/
def isSupported : IO Bool := FFI.wsCheckSupport

/-- WebSocket connection state -/
inductive ConnectionState where
  | connecting
  | open
  | closing
  | closed
  deriving Repr, Inhabited, BEq

/-- A WebSocket connection handle -/
structure Connection where
  private mk ::
  /-- The underlying curl easy handle -/
  private easy : FFI.Easy
  /-- Current connection state -/
  private stateRef : IO.Ref ConnectionState
  /-- URL connected to -/
  url : String

namespace Connection

/-- Get the current connection state -/
def getState (conn : Connection) : IO ConnectionState :=
  conn.stateRef.get

/-- Check if connection is open -/
def isOpen (conn : Connection) : IO Bool := do
  let state ← conn.getState
  return state == .open

/-- Connect to a WebSocket server.
    The URL should use ws:// or wss:// protocol.
    Returns a Connection on successful handshake. -/
def connect (url : String) (headers : Headers := #[]) : IO (WispResult Connection) := do
  -- Check WebSocket support
  let supported ← FFI.wsCheckSupport
  if !supported then
    return .error (.ioError "WebSocket support not available in libcurl. Requires curl 7.86+ with WebSocket enabled.")

  -- Validate URL protocol
  let isWs := url.startsWith "ws://" || url.startsWith "wss://"
  if !isWs then
    return .error (.ioError s!"Invalid WebSocket URL: {url}. Must use ws:// or wss:// protocol.")

  try
    -- Initialize easy handle
    let easy ← FFI.easyInit

    -- Setup callbacks for handshake response
    FFI.setupWriteCallback easy
    FFI.setupHeaderCallback easy

    -- Set URL
    FFI.setoptString easy FFI.CurlOpt.URL url

    -- Set CONNECT_ONLY to 2 for WebSocket upgrade
    -- Value 2 tells curl to do WebSocket upgrade handshake
    FFI.setoptLong easy FFI.CurlOpt.CONNECT_ONLY 2

    -- Build headers slist
    let slist ← FFI.slistNew

    -- Add user headers
    for (key, value) in headers do
      FFI.slistAppend slist s!"{key}: {value}"

    -- Apply headers
    FFI.setoptSlist easy FFI.CurlOpt.HTTPHEADER slist

    -- Create state ref
    let stateRef ← IO.mkRef ConnectionState.connecting

    -- Perform the connection/handshake
    FFI.easyPerform easy

    -- Update state to open
    stateRef.set .open

    return .ok { easy, stateRef, url }
  catch e =>
    return .error (.ioError s!"WebSocket connection failed: {e}")

/-- Send a WebSocket frame -/
def send (conn : Connection) (frame : WebSocketFrame) : IO (WispResult Unit) := do
  let state ← conn.getState
  if state != .open then
    return .error (.ioError "WebSocket connection is not open")

  try
    let flags := frame.frameType.toCurlFlags
    FFI.wsSend conn.easy frame.payload flags
    return .ok ()
  catch e =>
    return .error (.ioError s!"WebSocket send failed: {e}")

/-- Send a text message -/
def sendText (conn : Connection) (text : String) : IO (WispResult Unit) :=
  conn.send (WebSocketFrame.text text)

/-- Send binary data -/
def sendBinary (conn : Connection) (data : ByteArray) : IO (WispResult Unit) :=
  conn.send (WebSocketFrame.binary data)

/-- Send a ping frame -/
def sendPing (conn : Connection) (data : ByteArray := ByteArray.empty) : IO (WispResult Unit) :=
  conn.send (WebSocketFrame.ping data)

/-- Send a pong frame -/
def sendPong (conn : Connection) (data : ByteArray := ByteArray.empty) : IO (WispResult Unit) :=
  conn.send (WebSocketFrame.pong data)

/-- Receive a WebSocket frame (non-blocking).
    Returns none if no data available. -/
def recv (conn : Connection) : IO (WispResult (Option WebSocketFrame)) := do
  let state ← conn.getState
  if state == .closed then
    return .error (.ioError "WebSocket connection is closed")

  try
    -- FFI.wsRecv returns None for CURLE_AGAIN (no data available)
    -- and throws an exception for actual errors
    let result ← FFI.wsRecv conn.easy
    match result with
    | none => return .ok none
    | some (payload, flags) =>
      let frameType := WebSocketFrameType.fromCurlFlags flags
      let frame : WebSocketFrame := { frameType, payload }

      -- Handle close frame
      if frame.isClose then
        conn.stateRef.set .closed

      return .ok (some frame)
  catch e =>
    return .error (.ioError s!"WebSocket recv failed: {e}")

/-- Receive a WebSocket frame (blocking with timeout).
    Polls until a frame is received or timeout expires.
    timeout is in milliseconds. -/
partial def recvTimeout (conn : Connection) (timeout : UInt32 := 30000) : IO (WispResult (Option WebSocketFrame)) := do
  let startTime ← IO.monoMsNow
  let endTime : Nat := startTime + timeout.toNat

  let rec loop : IO (WispResult (Option WebSocketFrame)) := do
    let now ← IO.monoMsNow
    if now >= endTime then
      return .ok none

    let result ← conn.recv
    match result with
    | .error e => return .error e
    | .ok (some frame) => return .ok (some frame)
    | .ok none =>
      -- No data available, sleep briefly and retry
      IO.sleep 10
      loop

  loop

/-- Close the WebSocket connection gracefully -/
def close (conn : Connection) (code : UInt16 := WebSocketCloseCode.normal) (reason : String := "") : IO (WispResult Unit) := do
  let state ← conn.getState
  if state == .closed then
    return .ok ()

  conn.stateRef.set .closing

  try
    -- Send close frame
    let closeFrame := WebSocketFrame.close code reason
    let flags := closeFrame.frameType.toCurlFlags
    FFI.wsSend conn.easy closeFrame.payload flags

    conn.stateRef.set .closed
    return .ok ()
  catch e =>
    conn.stateRef.set .closed
    return .error (.ioError s!"WebSocket close failed: {e}")

/-- Run a message handler loop until the connection closes.
    Automatically responds to ping frames with pong.
    The handler is called for each non-control frame received. -/
partial def onMessage (conn : Connection) (handler : WebSocketFrame → IO Unit) : IO (WispResult Unit) := do
  let rec loop : IO (WispResult Unit) := do
    let state ← conn.getState
    if state != .open then
      return .ok ()

    let result ← conn.recv
    match result with
    | .error e => return .error e
    | .ok none =>
      -- No data, sleep briefly
      IO.sleep 10
      loop
    | .ok (some frame) =>
      -- Auto-respond to ping with pong
      if frame.isPing then
        let _ ← conn.sendPong frame.payload

      -- Handle close frame
      if frame.isClose then
        -- Echo close frame back
        let code := frame.closeCode.getD WebSocketCloseCode.normal
        let _ ← conn.close code
        return .ok ()

      -- Call handler for data frames
      if frame.frameType.isData then
        handler frame

      loop

  loop

end Connection

/-- Convenience function to connect to a WebSocket server -/
def connect (url : String) (headers : Headers := #[]) : IO (WispResult Connection) :=
  Connection.connect url headers

end Wisp.WebSocket
