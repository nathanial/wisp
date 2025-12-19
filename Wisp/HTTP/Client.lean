/-
  Wisp HTTP Client
  High-level HTTP client with builder pattern
-/

import Wisp.Core.Types
import Wisp.Core.Error
import Wisp.Core.Request
import Wisp.Core.Response
import Wisp.FFI.Easy
import Wisp.FFI.Multi
import Std.Data.HashMap
import Std.Sync.Channel
import Std.Sync.Mutex

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

private instance : Inhabited Wisp.WispError :=
  ⟨.ioError "uninitialized"⟩

private instance : Inhabited (Wisp.WispResult Wisp.Response) :=
  ⟨.error default⟩

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

-- ============================================================================
-- Async Manager (curl_multi)
-- ============================================================================

private structure Pending where
  easy : Wisp.FFI.Easy
  promise : IO.Promise (Wisp.WispResult Wisp.Response)

private inductive Command where
  | add (id : UInt64) (pending : Pending)

private def curlErrorFromCode (code : UInt32) : Wisp.WispError :=
  match Wisp.CurlCode.fromNat code.toNat with
  | .operationTimedout => .timeoutError "Operation timed out"
  | .couldntConnect => .connectionError "Couldn't connect"
  | .sslConnectError => .sslError "SSL connect error"
  | .peerFailedVerification => .sslError "Peer failed verification"
  | .sslCertProblem => .sslError "SSL certificate problem"
  | .sslInvalidcertstatus => .sslError "SSL invalid certificate status"
  | other => .curlError s!"{other}"

private def readResponse (easy : Wisp.FFI.Easy) : IO Wisp.Response := do
  let body ← Wisp.FFI.getResponseBody easy
  let rawHeaders ← Wisp.FFI.getResponseHeaders easy
  let status ← Wisp.FFI.getinfoLong easy Wisp.FFI.CurlInfo.RESPONSE_CODE
  let totalTime ← Wisp.FFI.getinfoDouble easy Wisp.FFI.CurlInfo.TOTAL_TIME
  let effectiveUrl ← Wisp.FFI.getinfoString easy Wisp.FFI.CurlInfo.EFFECTIVE_URL

  let headers := parseHeaders rawHeaders
  let contentType := headers.get? "Content-Type"

  return {
    status := status.toUInt32
    headers := headers
    body := body
    contentType := contentType
    totalTime := totalTime
    effectiveUrl := effectiveUrl
  }

private def handleCompletion
    (multi : Wisp.FFI.Multi)
    (pending : Std.HashMap UInt64 Pending) : IO (Std.HashMap UInt64 Pending) := do
  let mut pending := pending
  let mut msg ← Wisp.FFI.multiInfoRead multi
  while msg.isSome do
    match msg with
    | some (id, code) =>
      if let some p := pending.get? id then
        try
          if code == 0 then
            let resp ← readResponse p.easy
            p.promise.resolve (.ok resp)
          else
            p.promise.resolve (.error (curlErrorFromCode code))
        catch e =>
          p.promise.resolve (.error (.ioError (toString e)))
        Wisp.FFI.multiRemoveHandle multi p.easy
        pending := pending.erase id
    | none => pure ()
    msg ← Wisp.FFI.multiInfoRead multi
  return pending

private def handleCommand
    (multi : Wisp.FFI.Multi)
    (pending : Std.HashMap UInt64 Pending)
    (cmd : Command) : IO (Std.HashMap UInt64 Pending) := do
  match cmd with
  | .add id p =>
    Wisp.FFI.multiAddHandle multi p.easy
    return pending.insert id p

private def drainCommands
    (multi : Wisp.FFI.Multi)
    (pending : Std.HashMap UInt64 Pending)
    (chan : Std.CloseableChannel.Sync Command) : IO (Std.HashMap UInt64 Pending) := do
  let mut pending := pending
  let mut cmd? ← chan.tryRecv
  while cmd?.isSome do
    match cmd? with
    | some cmd =>
      pending ← handleCommand multi pending cmd
    | none => pure ()
    cmd? ← chan.tryRecv
  return pending

private partial def managerLoop (chan : Std.CloseableChannel.Sync Command) : IO Unit := do
  let multi ← Wisp.FFI.multiInit

  let rec loop (pending : Std.HashMap UInt64 Pending) : IO Unit := do
    if pending.isEmpty then
      let cmd? ← chan.recv
      match cmd? with
      | none => return ()
      | some cmd =>
        let pending ← handleCommand multi pending cmd
        loop pending
    else
      let pending ← drainCommands multi pending chan
      let _ ← Wisp.FFI.multiPerform multi
      let _ ← Wisp.FFI.multiPoll multi 100
      let pending ← handleCompletion multi pending
      loop pending

  loop {}

private structure Manager where
  chan : Std.CloseableChannel.Sync Command
  nextId : Std.Mutex UInt64
  worker : Task (Except IO.Error Unit)

private def startManager : IO Manager := do
  let chan ← Std.CloseableChannel.Sync.new
  let nextId ← Std.Mutex.new 1
  let worker ← (managerLoop chan).asTask Task.Priority.dedicated
  return { chan, nextId, worker }

initialize managerRef : IO.Ref (Option Manager) ← IO.mkRef none
initialize managerMutex : Std.Mutex Unit ← Std.Mutex.new ()

private def getManager : IO Manager := do
  managerMutex.atomically do
    let current ← managerRef.get
    match current with
    | some m => return m
    | none =>
      let m ← startManager
      managerRef.set (some m)
      return m

/-- Shutdown the async manager and stop background polling. -/
def shutdown : IO Unit := do
  let manager? ← managerMutex.atomically do
    let current ← managerRef.get
    match current with
    | none => return none
    | some m =>
      managerRef.set none
      return some m
  match manager? with
  | none => pure ()
  | some m =>
    try
      let _ ← Std.CloseableChannel.Sync.close m.chan
      let _ := m.worker.get
      pure ()
    catch _ =>
      pure ()

/-- Execute a request asynchronously and return a task for the response. -/
def execute (client : Client) (req : Wisp.Request) : IO (Task (Wisp.WispResult Wisp.Response)) := do
  try
    -- Initialize easy handle
    let easy ← Wisp.FFI.easyInit

    -- Setup response callbacks
    Wisp.FFI.setupWriteCallback easy
    Wisp.FFI.setupHeaderCallback easy

    -- Set URL
    Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.URL req.url

    -- Set method
    let customMethod : Option String :=
      match req.method with
      | .PUT => some "PUT"
      | .DELETE => some "DELETE"
      | .PATCH => some "PATCH"
      | .OPTIONS => some "OPTIONS"
      | .TRACE => some "TRACE"
      | .CONNECT => some "CONNECT"
      | _ => none

    match req.method with
    | .GET => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.HTTPGET 1
    | .POST => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.POST 1
    | .HEAD => Wisp.FFI.setoptLong easy Wisp.FFI.CurlOpt.NOBODY 1
    | _ => pure ()

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

    -- Re-apply custom method after setting body/options that may override it
    if let some method := customMethod then
      Wisp.FFI.setoptString easy Wisp.FFI.CurlOpt.CUSTOMREQUEST method

    -- Apply headers
    Wisp.FFI.setoptSlist easy Wisp.FFI.CurlOpt.HTTPHEADER slist

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

    -- Enqueue on async manager
    let manager ← getManager
    let id ← manager.nextId.atomically do
      let current ← get
      set (current + 1)
      return current
    Wisp.FFI.setoptPrivate easy id

    let promise ← IO.Promise.new
    let pending : Pending := { easy, promise }
    let _ ← Std.CloseableChannel.Sync.send manager.chan (.add id pending)

    return promise.result!
  catch e =>
    let promise ← IO.Promise.new
    promise.resolve (.error (.ioError (toString e)))
    return promise.result!

/-- Execute a request synchronously by awaiting the task. -/
def executeSync (client : Client) (req : Wisp.Request) : IO (Wisp.WispResult Wisp.Response) := do
  let task ← client.execute req
  return task.get

/-- Simple GET request -/
def get (client : Client) (url : String) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.get url)

/-- Simple POST request with JSON body -/
def postJson (client : Client) (url : String) (json : String) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.post url |>.withJson json)

/-- Simple POST request with form data -/
def postForm (client : Client) (url : String) (fields : Array (String × String)) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.post url |>.withForm fields)

/-- Simple PUT request with JSON body -/
def putJson (client : Client) (url : String) (json : String) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.put url |>.withJson json)

/-- Simple DELETE request -/
def delete (client : Client) (url : String) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.delete url)

/-- Simple HEAD request -/
def head (client : Client) (url : String) : IO (Task (Wisp.WispResult Wisp.Response)) :=
  client.execute (Wisp.Request.head url)

end Client

end Wisp.HTTP
