import WispTests.Common

open Crucible

namespace WispTests.SSEParser

testSuite "SSE Parser"

test "Parse basic SSE event" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: hello\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.data ≡ "hello"
    event.event ≡ "message"
  | none => throw (IO.userError "Expected SSE event")

test "Parse SSE event with type" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "event: update\ndata: {\"status\": \"ok\"}\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.event ≡ "update"
    shouldSatisfy (event.data.containsSubstr "status") "data contains status"
  | none => throw (IO.userError "Expected SSE event")

test "Parse SSE event with id" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "id: 123\ndata: test\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event =>
    event.id ≡ some "123"
    event.data ≡ "test"
  | none => throw (IO.userError "Expected SSE event")

test "Parse multiple SSE events" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: first\n\ndata: second\n\ndata: third\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let events ← stream.toArray
  events.size ≡ 3
  events[0]!.data ≡ "first"
  events[1]!.data ≡ "second"
  events[2]!.data ≡ "third"

test "Parse multiline SSE data" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "data: line1\ndata: line2\ndata: line3\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.data ≡ "line1\nline2\nline3"
  | none => throw (IO.userError "Expected SSE event")

test "Ignore SSE comments" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := ": this is a comment\ndata: actual data\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.data ≡ "actual data"
  | none => throw (IO.userError "Expected SSE event")

test "SSE retry field" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "retry: 5000\ndata: reconnect info\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let event? ← stream.recv
  match event? with
  | some event => event.retry ≡ some 5000
  | none => throw (IO.userError "Expected SSE event")

test "SSE lastEventId tracking" := do
  let channel ← Std.CloseableChannel.Sync.new (α := ByteArray)
  let sseData := "id: evt-001\ndata: first\n\nid: evt-002\ndata: second\n\n".toUTF8
  channel.send sseData
  channel.close
  let mockResp : Wisp.StreamingResponse := {
    status := 200
    headers := Wisp.Headers.empty
    bodyChannel := channel
  }
  let stream ← Wisp.HTTP.SSE.Stream.fromStreaming mockResp
  let _ ← stream.recv  -- First event
  let _ ← stream.recv  -- Second event
  let lastId ← stream.getLastEventId
  lastId ≡ some "evt-002"



end WispTests.SSEParser
