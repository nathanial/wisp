/-
  Wisp SSE (Server-Sent Events) Parser
  Parses SSE events from streaming HTTP responses
-/

import Wisp.Core.Streaming

namespace Wisp.HTTP.SSE

/-- A parsed SSE event -/
structure Event where
  /-- Event type (default: "message") -/
  event : String := "message"
  /-- Event data (may span multiple `data:` lines, joined by newlines) -/
  data : String
  /-- Optional event ID -/
  id : Option String := none
  /-- Optional retry interval in milliseconds -/
  retry : Option Nat := none
  deriving Repr, Inhabited

namespace Event

/-- Check if this is the default "message" event type -/
def isMessage (e : Event) : Bool := e.event == "message"

/-- Check if this event has an ID -/
def hasId (e : Event) : Bool := e.id.isSome

/-- Check if this event requests a retry interval change -/
def hasRetry (e : Event) : Bool := e.retry.isSome

end Event

/-- Internal parser state for building an event -/
private structure ParserState where
  eventType : String := "message"
  dataLines : Array String := #[]
  eventId : Option String := none
  retry : Option Nat := none
  deriving Inhabited

namespace ParserState

/-- Reset state for next event -/
def reset : ParserState := {}

/-- Check if we have any data to dispatch -/
def hasData (s : ParserState) : Bool := !s.dataLines.isEmpty

/-- Build an Event from current state -/
def toEvent (s : ParserState) : Event :=
  { event := s.eventType
    data := "\n".intercalate s.dataLines.toList
    id := s.eventId
    retry := s.retry }

end ParserState

/-- SSE stream that parses events from a streaming response -/
structure Stream where
  /-- The underlying streaming response body channel -/
  bodyChannel : Std.CloseableChannel.Sync ByteArray
  /-- Buffer for accumulating partial data between chunks -/
  buffer : IO.Ref String
  /-- Last event ID received (for reconnection) -/
  lastEventId : IO.Ref (Option String)
  /-- Current parser state -/
  parserState : IO.Ref ParserState
  /-- Queue of parsed events ready to be consumed -/
  eventQueue : IO.Ref (Array Event)

namespace Stream

/-- Create an SSE stream from a streaming response -/
def fromStreaming (resp : Wisp.StreamingResponse) : IO Stream := do
  let buffer ← IO.mkRef ""
  let lastEventId ← IO.mkRef none
  let parserState ← IO.mkRef ParserState.reset
  let eventQueue ← IO.mkRef #[]
  return {
    bodyChannel := resp.bodyChannel
    buffer := buffer
    lastEventId := lastEventId
    parserState := parserState
    eventQueue := eventQueue
  }

/-- Strip a field prefix and return the value, handling optional space after colon -/
private def stripField (line : String) (fieldPrefix : String) : Option String :=
  if line.startsWith fieldPrefix then
    let rest := line.drop fieldPrefix.length
    -- SSE spec: if first char after colon is space, strip it
    if rest.startsWith " " then some (rest.drop 1)
    else some rest
  else
    none

/-- Parse a single SSE line and update parser state -/
private def parseLine (state : ParserState) (line : String) : ParserState × Option Event :=
  -- Empty line = dispatch event if we have data
  if line.isEmpty then
    if state.hasData then
      let event := state.toEvent
      (ParserState.reset, some event)
    else
      (state, none)
  -- Comment line (starts with :)
  else if line.startsWith ":" then
    (state, none)
  -- event: field
  else if let some value := stripField line "event:" then
    ({ state with eventType := value }, none)
  -- data: field
  else if let some value := stripField line "data:" then
    ({ state with dataLines := state.dataLines.push value }, none)
  -- id: field (no colon in value per spec)
  else if let some value := stripField line "id:" then
    if value.contains ':' then
      (state, none)  -- Invalid: id cannot contain colon
    else
      ({ state with eventId := some value }, none)
  -- retry: field (must be digits only)
  else if let some value := stripField line "retry:" then
    match value.trim.toNat? with
    | some n => ({ state with retry := some n }, none)
    | none => (state, none)  -- Invalid: non-numeric retry
  else
    -- Unknown field, ignore per spec
    (state, none)

/-- Process buffered text into lines, keeping incomplete final line in buffer -/
private def processBuffer (text : String) : Array String × String :=
  -- Split on \n (SSE uses \n, \r\n, or \r as line endings)
  -- We normalize by replacing \r\n and \r with \n first
  let normalized := text.replace "\r\n" "\n" |>.replace "\r" "\n"
  let parts := normalized.splitOn "\n"
  match parts with
  | [] => (#[], "")
  | [single] =>
    -- No newline found, keep everything in buffer
    (#[], single)
  | _ =>
    -- Last element is either empty (if text ended with \n) or incomplete line
    let lines := parts.dropLast.toArray
    let remaining := parts.getLast!
    (lines, remaining)

/-- Read the next SSE event from the stream (blocks until event or EOF) -/
partial def recv (s : Stream) : IO (Option Event) := do
  -- First check if we have queued events
  let queue ← s.eventQueue.get
  if h : queue.size > 0 then
    let event := queue[0]
    s.eventQueue.set (queue.eraseIdx 0)
    -- Update lastEventId if present
    if let some id := event.id then
      s.lastEventId.set (some id)
    return some event
  else
    -- Need to read more data and parse
    let chunk? ← s.bodyChannel.recv
    match chunk? with
    | none =>
      -- EOF - check if there's a pending event in parser state
      let state ← s.parserState.get
      if state.hasData then
        let event := state.toEvent
        s.parserState.set ParserState.reset
        if let some id := event.id then
          s.lastEventId.set (some id)
        return some event
      else
        return none
    | some chunk =>
      -- Decode chunk and append to buffer
      let chunkStr := String.fromUTF8! chunk
      let buf ← s.buffer.get
      let combined := buf ++ chunkStr
      let (lines, remaining) := processBuffer combined
      s.buffer.set remaining

      -- Parse each line
      let mut state ← s.parserState.get
      let mut events : Array Event := #[]
      for line in lines do
        let (newState, maybeEvent) := parseLine state line
        state := newState
        if let some event := maybeEvent then
          events := events.push event
      s.parserState.set state

      -- If we got events, queue them and return first
      if h : events.size > 0 then
        let first := events[0]
        if events.size > 1 then
          s.eventQueue.set (events.eraseIdx 0)
        if let some id := first.id then
          s.lastEventId.set (some id)
        return some first
      else
        -- No complete events yet, recurse to read more
        s.recv

/-- Iterate over all events in the stream -/
partial def forEachEvent (s : Stream) (f : Event → IO Unit) : IO Unit := do
  let rec loop : IO Unit := do
    let event? ← s.recv
    match event? with
    | some event =>
      f event
      loop
    | none => return ()
  loop

/-- Collect all events from the stream into an array -/
partial def toArray (s : Stream) : IO (Array Event) := do
  let rec loop (acc : Array Event) : IO (Array Event) := do
    let event? ← s.recv
    match event? with
    | some event => loop (acc.push event)
    | none => return acc
  loop #[]

/-- Get the last event ID received (useful for reconnection) -/
def getLastEventId (s : Stream) : IO (Option String) :=
  s.lastEventId.get

end Stream

end Wisp.HTTP.SSE
