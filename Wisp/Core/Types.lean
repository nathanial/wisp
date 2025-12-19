/-
  Wisp Core Types
  HTTP methods, headers, and URL types
-/

namespace Wisp

/-- HTTP request methods -/
inductive Method where
  | GET
  | POST
  | PUT
  | DELETE
  | PATCH
  | HEAD
  | OPTIONS
  | TRACE
  | CONNECT
  deriving Repr, BEq, Inhabited

namespace Method

def toString : Method → String
  | GET => "GET"
  | POST => "POST"
  | PUT => "PUT"
  | DELETE => "DELETE"
  | PATCH => "PATCH"
  | HEAD => "HEAD"
  | OPTIONS => "OPTIONS"
  | TRACE => "TRACE"
  | CONNECT => "CONNECT"

instance : ToString Method := ⟨toString⟩

end Method

/-- HTTP version -/
inductive HttpVersion where
  | HTTP1_0
  | HTTP1_1
  | HTTP2
  | HTTP3
  deriving Repr, BEq, Inhabited

/-- A single HTTP header (key-value pair) -/
abbrev Header := String × String

/-- Collection of HTTP headers -/
abbrev Headers := Array Header

namespace Headers

/-- Empty headers collection -/
def empty : Headers := #[]

/-- Add a header to the collection -/
def add (headers : Headers) (key : String) (value : String) : Headers :=
  headers.push (key, value)

/-- Get a header value by name (case-insensitive) -/
def get? (headers : Headers) (key : String) : Option String :=
  headers.findSome? fun (k, v) =>
    if k.toLower == key.toLower then some v else none

/-- Get all values for a header name (case-insensitive) -/
def getAll (headers : Headers) (key : String) : Array String :=
  headers.filterMap fun (k, v) =>
    if k.toLower == key.toLower then some v else none

/-- Check if a header exists (case-insensitive) -/
def contains (headers : Headers) (key : String) : Bool :=
  headers.any fun (k, _) => k.toLower == key.toLower

/-- Remove all headers with the given name (case-insensitive) -/
def remove (headers : Headers) (key : String) : Headers :=
  headers.filter fun (k, _) => k.toLower != key.toLower

/-- Convert headers to curl-style strings ("Key: Value") -/
def toCurlStrings (headers : Headers) : Array String :=
  headers.map fun (k, v) => s!"{k}: {v}"

/-- Get Content-Type header -/
def contentType (headers : Headers) : Option String :=
  headers.get? "Content-Type"

/-- Get Content-Length header -/
def contentLength (headers : Headers) : Option Nat := do
  let value ← headers.get? "Content-Length"
  value.toNat?

end Headers

end Wisp
