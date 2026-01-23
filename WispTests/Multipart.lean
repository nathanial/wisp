import WispTests.Common

open Crucible

namespace WispTests.Multipart

testSuite "Multipart Form Uploads"

test "Multipart text field" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "field1", data := "value1".toUTF8 },
    { name := "field2", data := "value2".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "multipart POST"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "field1") "response contains field1"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "value1") "response contains value1"

test "Multipart with filename" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "file", filename := some "test.txt", contentType := some "text/plain", data := "file contents here".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "multipart file upload"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "files") "response contains files section"
  shouldSatisfy (r.bodyTextLossy.containsSubstr "file contents here") "response contains file content"

test "Multipart with content type" := do
  let parts : Array Wisp.MultipartPart := #[
    { name := "jsondata", contentType := some "application/json", data := "{\"key\": \"value\"}".toUTF8 }
  ]
  let req := Wisp.Request.post "https://httpbin.org/post" |>.withMultipart parts
  let result ← awaitTask (client.execute req)
  let r ← shouldBeOk result "multipart JSON"
  r.status ≡ 200
  shouldSatisfy (r.bodyTextLossy.containsSubstr "jsondata") "response contains jsondata"



end WispTests.Multipart
