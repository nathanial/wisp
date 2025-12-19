/-
  Wisp HTTP Client
  High-level HTTP client with builder pattern
-/

import Wisp.Core.Types
import Wisp.Core.Error
import Wisp.Core.Request
import Wisp.Core.Response
import Wisp.FFI.Easy

namespace Wisp.HTTP

/-- HTTP Client configuration -/
structure Client where
  /-- Default user agent string -/
  userAgent : String := "Wisp/1.0 (Lean4)"
  /-- Default timeout in milliseconds -/
  defaultTimeout : UInt64 := 30000
  /-- Default connection timeout in milliseconds -/
  defaultConnectTimeout : UInt64 := 10000
  /-- Follow redirects by default -/
  followRedirects : Bool := true
  /-- Maximum redirects -/
  maxRedirects : UInt32 := 10
  /-- Verify SSL by default -/
  verifySsl : Bool := true
  deriving Repr, Inhabited

namespace Client

/-- Create a new HTTP client with default settings -/
def new : Client := {}

/-- Set custom user agent -/
def withUserAgent (c : Client) (ua : String) : Client :=
  { c with userAgent := ua }

/-- Set default timeout -/
def withTimeout (c : Client) (ms : UInt64) : Client :=
  { c with defaultTimeout := ms }

/-- Set default connection timeout -/
def withConnectTimeout (c : Client) (ms : UInt64) : Client :=
  { c with defaultConnectTimeout := ms }

/-- Enable/disable following redirects -/
def withFollowRedirects (c : Client) (follow : Bool) : Client :=
  { c with followRedirects := follow }

/-- Enable/disable SSL verification -/
def withSslVerify (c : Client) (verify : Bool) : Client :=
  { c with verifySsl := verify }

/-- Find index of character in string -/
private def findCharIdx (s : String) (c : Char) : Option Nat := do
  let chars := s.toList
  for i in [:chars.length] do
    if chars[i]! == c then
      return i
  none

/-- Parse raw header string into Headers array -/
private def parseHeaders (raw : String) : Wisp.Headers := Id.run do
  let lines := raw.splitOn "\r\n"
  let mut headers : Wisp.Headers := #[]
  for line in lines do
    -- Skip empty lines and status lines
    if line.isEmpty || line.startsWith "HTTP/" then
      continue
    -- Find the colon separator
    if let some colonIdx := findCharIdx line ':' then
      let key := (line.take colonIdx).trim
      let value := (line.drop (colonIdx + 1)).trim
      if !key.isEmpty then
        headers := headers.push (key, value)
  headers

/-- URL-encode a form field value -/
private def urlEncodeField (easy : Wisp.FFI.Easy) (s : String) : IO String := do
  Wisp.FFI.urlEncode easy s

/-- Build form-encoded body string -/
private def buildFormBody (easy : Wisp.FFI.Easy) (fields : Array (String × String)) : IO String := do
  let mut parts : Array String := #[]
  for (key, value) in fields do
    let encodedKey ← urlEncodeField easy key
    let encodedValue ← urlEncodeField easy value
    parts := parts.push s!"{encodedKey}={encodedValue}"
  return "&".intercalate parts.toList

/-- Execute a request and return a response -/
def execute (client : Client) (req : Wisp.Request) : IO (Wisp.WispResult Wisp.Response) := do
  try
    -- Initialize easy handle
    let easy ← Wisp.FFI.easyInit

    -- Setup response callbacks
    Wisp.FFI.setupWriteCallback easy
    Wisp.FFI.setupHeaderCallback easy

    -- Set URL
    Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.URL req.url

    -- Set method
    match req.method with
    | .GET => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.HTTPGET 1
    | .POST => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POST 1
    | .HEAD => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.NOBODY 1
    | .PUT => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "PUT"
    | .DELETE => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "DELETE"
    | .PATCH => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "PATCH"
    | .OPTIONS => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "OPTIONS"
    | .TRACE => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "TRACE"
    | .CONNECT => Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST "CONNECT"

    -- Build headers slist
    let slist ← Wisp.FFI.slistNew

    -- Add user headers
    for (key, value) in req.headers do
      Wisp.FFI.slistAppend slist s!"{key}: {value}"

    -- Set body based on type
    match req.body with
    | .empty => pure ()
    | .raw data contentType =>
      Wisp.FFI.slistAppend slist s!"Content-Type: {contentType}"
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.POSTFIELDS (String.fromUTF8! data)
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POSTFIELDSIZE data.size.toInt64
    | .text content =>
      Wisp.FFI.slistAppend slist "Content-Type: text/plain; charset=utf-8"
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.POSTFIELDS content
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POSTFIELDSIZE content.length.toInt64
    | .json content =>
      Wisp.FFI.slistAppend slist "Content-Type: application/json; charset=utf-8"
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.POSTFIELDS content
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POSTFIELDSIZE content.length.toInt64
    | .form fields =>
      Wisp.FFI.slistAppend slist "Content-Type: application/x-www-form-urlencoded"
      let formBody ← buildFormBody easy fields
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.POSTFIELDS formBody
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POSTFIELDSIZE formBody.length.toInt64
    | .multipart parts =>
      let mime ← Wisp.FFI.mimeInit easy
      for p in parts do
        let mimepart ← Wisp.FFI.mimeAddpart mime
        Wisp.FFI.mimepartName mimepart p.name
        Wisp.FFI.mimepartData mimepart p.data
        if let some filename := p.filename then
          Wisp.FFI.mimepartFilename mimepart filename
        if let some ct := p.contentType then
          Wisp.FFI.mimepartType mimepart ct
      Wisp.FFI.setoptMime easy mime

    -- Apply headers
    Wisp.FFI.setoptSlist easy Wisp.FFI.CurlOpt.HTTPHEADER slist

    -- Set authentication
    match req.auth with
    | .none => pure ()
    | .basic username password =>
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.USERPWD s!"{username}:{password}"
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.HTTPAUTH Wisp.FFI.CurlOpt.AUTH_BASIC
    | .bearer token =>
      Wisp.FFI.slistAppend slist s!"Authorization: Bearer {token}"
    | .digest username password =>
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.USERPWD s!"{username}:{password}"
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.HTTPAUTH Wisp.FFI.CurlOpt.AUTH_DIGEST

    -- Set timeouts
    let timeout := if req.timeoutMs > 0 then req.timeoutMs else client.defaultTimeout
    let connectTimeout := if req.connectTimeoutMs > 0 then req.connectTimeoutMs else client.defaultConnectTimeout
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.TIMEOUT_MS timeout.toInt64
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.CONNECTTIMEOUT_MS connectTimeout.toInt64

    -- Set redirect behavior
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.FOLLOWLOCATION (if req.followRedirects then 1 else 0)
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.MAXREDIRS req.maxRedirects.toNat.toInt64

    -- Set SSL options
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.SSL_VERIFYPEER (if req.ssl.verifyPeer then 1 else 0)
    Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.SSL_VERIFYHOST (if req.ssl.verifyHost then 2 else 0)
    if let some caPath := req.ssl.caCertPath then
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CAINFO caPath
    if let some certPath := req.ssl.clientCertPath then
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.SSLCERT certPath
    if let some keyPath := req.ssl.clientKeyPath then
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.SSLKEY keyPath

    -- Set user agent
    Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.USERAGENT req.userAgent

    -- Set accept encoding
    if let some enc := req.acceptEncoding then
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.ACCEPT_ENCODING enc

    -- Enable verbose if requested
    if req.verbose then
      Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.VERBOSE 1

    -- Perform the request
    Wisp.FFI.easyPerform easy

    -- Get response data
    let body ← Wisp.FFI.getResponseBody easy
    let rawHeaders ← Wisp.FFI.getResponseHeaders easy
    let status ← Wisp.FFI.getinfoLong easy Wisp.FFI.CurlInfo.RESPONSE_CODE
    let totalTime ← Wisp.FFI.getinfoDouble easy Wisp.FFI.CurlInfo.TOTAL_TIME
    let effectiveUrl ← Wisp.FFI.getinfoString easy Wisp.FFI.CurlInfo.EFFECTIVE_URL

    -- Parse headers
    let headers := parseHeaders rawHeaders
    let contentType := headers.get? "Content-Type"

    return .ok {
      status := status.toUInt32
      headers := headers
      body := body
      contentType := contentType
      totalTime := totalTime
      effectiveUrl := effectiveUrl
    }

  catch e =>
    return .error (.ioError (toString e))

/-- Simple GET request -/
def get (client : Client) (url : String) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.get url)

/-- Simple POST request with JSON body -/
def postJson (client : Client) (url : String) (json : String) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.post url |>.withJson json)

/-- Simple POST request with form data -/
def postForm (client : Client) (url : String) (fields : Array (String × String)) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.post url |>.withForm fields)

/-- Simple PUT request with JSON body -/
def putJson (client : Client) (url : String) (json : String) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.put url |>.withJson json)

/-- Simple DELETE request -/
def delete (client : Client) (url : String) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.delete url)

/-- Simple HEAD request -/
def head (client : Client) (url : String) : IO (Wisp.WispResult Wisp.Response) :=
  client.execute (Wisp.Request.head url)

end Client

end Wisp.HTTP
