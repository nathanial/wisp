import WispTests.Common

open Crucible

namespace WispTests.Streaming

testSuite "Streaming Responses"

test "Stream response body" := do
  let req := Wisp.Request.get "https://httpbin.org/stream-bytes/1000"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream bytes"
  let body ← stream.readAllBody
  stream.status ≡ 200
  body.size ≡ 1000

test "Stream with forEachChunk" := do
  let req := Wisp.Request.get "https://httpbin.org/stream-bytes/500"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream chunks"
  let totalRef ← IO.mkRef (0 : Nat)
  stream.forEachChunk fun chunk => do
    let cur ← totalRef.get
    totalRef.set (cur + chunk.size)
  let total ← totalRef.get
  stream.status ≡ 200
  total ≡ 500

test "Streaming status check helpers" := do
  let req := Wisp.Request.get "https://httpbin.org/status/201"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream 201"
  let _ ← stream.readAllBody
  shouldSatisfy stream.isSuccess "isSuccess"
  shouldSatisfy (!stream.isError) "not isError"

test "Streaming 404 response" := do
  let req := Wisp.Request.get "https://httpbin.org/status/404"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream 404"
  let _ ← stream.readAllBody
  stream.status ≡ 404
  shouldSatisfy stream.isClientError "isClientError"

test "Streaming headers accessible" := do
  let req := Wisp.Request.get "https://httpbin.org/response-headers?X-Custom=streaming-test"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream headers"
  let _ ← stream.readAllBody
  shouldSatisfy (stream.headers.get? "X-Custom").isSome "X-Custom header present"

test "Streaming read body as text" := do
  let req := Wisp.Request.get "https://httpbin.org/json"
  let task ← client.executeStreaming req
  let stream ← shouldBeOk task.get "stream text"
  let bodyText ← stream.readAllBodyText
  match bodyText with
  | some text => shouldSatisfy (text.containsSubstr "slideshow") "body contains slideshow"
  | none => throw (IO.userError "Expected text body")



end WispTests.Streaming
