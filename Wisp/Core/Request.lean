/-
  Wisp Request Builder
  Fluent API for constructing HTTP requests
-/

import Wisp.Core.Types

namespace Wisp

/-- A part in a multipart form -/
structure MultipartPart where
  /-- Field name -/
  name : String
  /-- Optional filename (for file uploads) -/
  filename : Option String := none
  /-- Optional content type -/
  contentType : Option String := none
  /-- Part data -/
  data : ByteArray
  deriving Inhabited

/-- Request body types -/
inductive Body where
  /-- No request body -/
  | empty
  /-- Raw bytes with content type -/
  | raw (data : ByteArray) (contentType : String)
  /-- Plain text body -/
  | text (content : String)
  /-- JSON body -/
  | json (content : String)
  /-- URL-encoded form data -/
  | form (fields : Array (String × String))
  /-- Multipart form data (for file uploads) -/
  | multipart (parts : Array MultipartPart)
  deriving Inhabited

/-- Authentication methods -/
inductive Auth where
  /-- No authentication -/
  | none
  /-- HTTP Basic authentication -/
  | basic (username : String) (password : String)
  /-- Bearer token authentication -/
  | bearer (token : String)
  /-- HTTP Digest authentication -/
  | digest (username : String) (password : String)
  deriving Inhabited

/-- SSL/TLS verification options -/
structure SslOptions where
  /-- Verify the SSL certificate -/
  verifyPeer : Bool := true
  /-- Verify the hostname matches the certificate -/
  verifyHost : Bool := true
  /-- Path to CA certificate bundle -/
  caCertPath : Option String := none
  /-- Path to client certificate -/
  clientCertPath : Option String := none
  /-- Path to client private key -/
  clientKeyPath : Option String := none
  deriving Inhabited

/-- Cookie jar configuration for automatic cookie handling -/
structure CookieJar where
  /-- File to read cookies from (use "" to enable in-memory cookie engine) -/
  cookieFile : Option String := none
  /-- File to write cookies to after request completes -/
  cookieJarFile : Option String := none
  /-- Inline cookie string to send (format: "name1=value1; name2=value2") -/
  cookies : Option String := none
  deriving Inhabited

/-- HTTP Request with builder pattern -/
structure Request where
  /-- HTTP method -/
  method : Method := .GET
  /-- Target URL -/
  url : String
  /-- Request headers -/
  headers : Headers := #[]
  /-- Request body -/
  body : Body := .empty
  /-- Authentication -/
  auth : Auth := .none
  /-- Request timeout in milliseconds -/
  timeoutMs : UInt64 := 30000
  /-- Connection timeout in milliseconds -/
  connectTimeoutMs : UInt64 := 10000
  /-- Follow HTTP redirects -/
  followRedirects : Bool := true
  /-- Maximum number of redirects to follow -/
  maxRedirects : UInt32 := 10
  /-- SSL/TLS options -/
  ssl : SslOptions := {}
  /-- User agent string -/
  userAgent : String := "Wisp/1.0 (Lean4)"
  /-- Accept-Encoding header value -/
  acceptEncoding : Option String := some "gzip, deflate"
  /-- Cookie jar configuration -/
  cookieJar : CookieJar := {}
  /-- Enable verbose curl output (for debugging) -/
  verbose : Bool := false
  deriving Inhabited

namespace Request

/-- Create a GET request -/
def get (url : String) : Request :=
  { url, method := .GET }

/-- Create a POST request -/
def post (url : String) : Request :=
  { url, method := .POST }

/-- Create a PUT request -/
def put (url : String) : Request :=
  { url, method := .PUT }

/-- Create a DELETE request -/
def delete (url : String) : Request :=
  { url, method := .DELETE }

/-- Create a PATCH request -/
def patch (url : String) : Request :=
  { url, method := .PATCH }

/-- Create a HEAD request -/
def head (url : String) : Request :=
  { url, method := .HEAD }

/-- Create an OPTIONS request -/
def options (url : String) : Request :=
  { url, method := .OPTIONS }

/-- Set the HTTP method -/
def withMethod (r : Request) (m : Method) : Request :=
  { r with method := m }

/-- Add a single header -/
def withHeader (r : Request) (key : String) (value : String) : Request :=
  { r with headers := r.headers.add key value }

/-- Add multiple headers -/
def withHeaders (r : Request) (hs : Headers) : Request :=
  { r with headers := r.headers ++ hs }

/-- Set raw body with content type -/
def withBody (r : Request) (data : ByteArray) (contentType : String := "application/octet-stream") : Request :=
  { r with body := .raw data contentType }

/-- Set plain text body -/
def withText (r : Request) (content : String) : Request :=
  { r with body := .text content }

/-- Set JSON body -/
def withJson (r : Request) (json : String) : Request :=
  { r with body := .json json }

/-- Set form-urlencoded body -/
def withForm (r : Request) (fields : Array (String × String)) : Request :=
  { r with body := .form fields }

/-- Set multipart form body -/
def withMultipart (r : Request) (parts : Array MultipartPart) : Request :=
  { r with body := .multipart parts }

/-- Set basic authentication -/
def withBasicAuth (r : Request) (username : String) (password : String) : Request :=
  { r with auth := .basic username password }

/-- Set bearer token authentication -/
def withBearerToken (r : Request) (token : String) : Request :=
  { r with auth := .bearer token }

/-- Set digest authentication -/
def withDigestAuth (r : Request) (username : String) (password : String) : Request :=
  { r with auth := .digest username password }

/-- Set request timeout in milliseconds -/
def withTimeout (r : Request) (ms : UInt64) : Request :=
  { r with timeoutMs := ms }

/-- Set connection timeout in milliseconds -/
def withConnectTimeout (r : Request) (ms : UInt64) : Request :=
  { r with connectTimeoutMs := ms }

/-- Enable/disable following redirects -/
def withFollowRedirects (r : Request) (follow : Bool) (maxRedirects : UInt32 := 10) : Request :=
  { r with followRedirects := follow, maxRedirects := maxRedirects }

/-- Configure SSL options -/
def withSsl (r : Request) (opts : SslOptions) : Request :=
  { r with ssl := opts }

/-- Disable SSL verification (dangerous for production!) -/
def withInsecure (r : Request) : Request :=
  { r with ssl := { verifyPeer := false, verifyHost := false } }

/-- Set user agent string -/
def withUserAgent (r : Request) (ua : String) : Request :=
  { r with userAgent := ua }

/-- Set accept encoding -/
def withAcceptEncoding (r : Request) (encoding : Option String) : Request :=
  { r with acceptEncoding := encoding }

/-- Enable verbose output -/
def withVerbose (r : Request) (verbose : Bool := true) : Request :=
  { r with verbose := verbose }

/-- Configure cookie jar with file paths for reading and writing cookies -/
def withCookieJar (r : Request) (readFile : Option String := none) (writeFile : Option String := none) : Request :=
  { r with cookieJar := { cookieFile := readFile, cookieJarFile := writeFile } }

/-- Enable in-memory cookie handling (persists cookies across redirects within same request) -/
def withCookieEngine (r : Request) : Request :=
  { r with cookieJar := { cookieFile := some "" } }

/-- Set a cookie string to send (format: "name1=value1; name2=value2") -/
def withCookies (r : Request) (cookies : String) : Request :=
  { r with cookieJar := { r.cookieJar with cookies := some cookies } }

end Request

end Wisp
