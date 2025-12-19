/-
  Wisp Response Type
  HTTP response with status, headers, and body
-/

import Wisp.Core.Types

namespace Wisp

/-- HTTP Response -/
structure Response where
  /-- HTTP status code (e.g., 200, 404, 500) -/
  status : UInt32
  /-- Response headers -/
  headers : Headers
  /-- Response body as raw bytes -/
  body : ByteArray
  /-- Content-Type from headers (cached for convenience) -/
  contentType : Option String := none
  /-- Total transfer time in seconds -/
  totalTime : Float := 0.0
  /-- Effective URL after redirects -/
  effectiveUrl : String := ""
  deriving Inhabited

namespace Response

/-- Check if response status indicates success (2xx) -/
def isSuccess (r : Response) : Bool :=
  r.status >= 200 && r.status < 300

/-- Check if response status indicates redirect (3xx) -/
def isRedirect (r : Response) : Bool :=
  r.status >= 300 && r.status < 400

/-- Check if response status indicates client error (4xx) -/
def isClientError (r : Response) : Bool :=
  r.status >= 400 && r.status < 500

/-- Check if response status indicates server error (5xx) -/
def isServerError (r : Response) : Bool :=
  r.status >= 500 && r.status < 600

/-- Check if response indicates any error (4xx or 5xx) -/
def isError (r : Response) : Bool :=
  r.status >= 400

/-- Get body as UTF-8 string, returning none if invalid UTF-8 -/
def bodyText (r : Response) : Option String :=
  String.fromUTF8? r.body

/-- Get body as UTF-8 string, replacing invalid sequences with replacement character -/
def bodyTextLossy (r : Response) : String :=
  match String.fromUTF8? r.body with
  | some s => s
  | none =>
    -- Fall back to byte-by-byte conversion, replacing non-ASCII with replacement char
    let chars := r.body.toList.map fun b =>
      if b < 128 then Char.ofNat b.toNat else '�'
    String.mk chars

/-- Get header value by name (case-insensitive) -/
def header (r : Response) (name : String) : Option String :=
  r.headers.get? name

/-- Get body size in bytes -/
def bodySize (r : Response) : Nat :=
  r.body.size

/-- Check if body is empty -/
def isEmpty (r : Response) : Bool :=
  r.body.isEmpty

/-- Get status code as string description -/
def statusText (r : Response) : String :=
  match r.status.toNat with
  | 100 => "Continue"
  | 101 => "Switching Protocols"
  | 200 => "OK"
  | 201 => "Created"
  | 202 => "Accepted"
  | 204 => "No Content"
  | 301 => "Moved Permanently"
  | 302 => "Found"
  | 303 => "See Other"
  | 304 => "Not Modified"
  | 307 => "Temporary Redirect"
  | 308 => "Permanent Redirect"
  | 400 => "Bad Request"
  | 401 => "Unauthorized"
  | 403 => "Forbidden"
  | 404 => "Not Found"
  | 405 => "Method Not Allowed"
  | 408 => "Request Timeout"
  | 409 => "Conflict"
  | 410 => "Gone"
  | 429 => "Too Many Requests"
  | 500 => "Internal Server Error"
  | 501 => "Not Implemented"
  | 502 => "Bad Gateway"
  | 503 => "Service Unavailable"
  | 504 => "Gateway Timeout"
  | _ => s!"Status {r.status}"

end Response

end Wisp
