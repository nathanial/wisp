import WispTests.Common

open Crucible

namespace WispTests.WebSocket

testSuite "WebSocket"

test "WebSocket support check" := do
  let supported ← Wisp.FFI.wsCheckSupport
  -- With Homebrew curl 8.11+, WebSocket should be supported
  shouldSatisfy supported "WebSocket support available"

test "WebSocket frame type conversions" := do
  -- Test frame type round-trip conversion
  let textFlags := Wisp.WebSocketFrameType.text.toCurlFlags
  let binaryFlags := Wisp.WebSocketFrameType.binary.toCurlFlags
  let pingFlags := Wisp.WebSocketFrameType.ping.toCurlFlags

  shouldBe (Wisp.WebSocketFrameType.fromCurlFlags textFlags) .text
  shouldBe (Wisp.WebSocketFrameType.fromCurlFlags binaryFlags) .binary
  shouldBe (Wisp.WebSocketFrameType.fromCurlFlags pingFlags) .ping

test "WebSocket frame constructors" := do
  let textFrame := Wisp.WebSocketFrame.text "hello"
  shouldBe textFrame.frameType .text
  shouldSatisfy (textFrame.payload == "hello".toUTF8) "text payload matches"

  let binData := ByteArray.mk #[1, 2, 3]
  let binFrame := Wisp.WebSocketFrame.binary binData
  shouldBe binFrame.frameType .binary
  shouldSatisfy (binFrame.payload == binData) "binary payload matches"

  let closeFrame := Wisp.WebSocketFrame.close 1000 "goodbye"
  shouldBe closeFrame.frameType .close
  shouldBe closeFrame.closeCode (some 1000)

test "WebSocket close code parsing" := do
  let closeFrame := Wisp.WebSocketFrame.close 1001 "going away"
  shouldBe closeFrame.closeCode (some 1001)
  shouldBe closeFrame.closeReason (some "going away")

test "WebSocket invalid URL rejected" := do
  let result ← Wisp.WebSocket.connect "http://example.com"
  match result with
  | .error _ =>
    -- Just verify we got an error for an invalid URL
    shouldSatisfy true "invalid URL rejected"
  | .ok _ => throw (IO.userError "Expected error for http:// URL")



end WispTests.WebSocket
