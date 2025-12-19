/-
  Wisp Error Types
  Error handling for curl operations
-/

namespace Wisp

/-- Curl error codes (common subset) -/
inductive CurlCode where
  | ok
  | unsupportedProtocol
  | failedInit
  | urlMalformat
  | couldntResolveProxy
  | couldntResolveHost
  | couldntConnect
  | weirdServerReply
  | remoteAccessDenied
  | ftpAcceptFailed
  | ftpAcceptTimeout
  | ftpBadPassword
  | ftpCantGetHost
  | httpReturnedError
  | writeError
  | uploadFailed
  | readError
  | outOfMemory
  | operationTimedout
  | rangeError
  | httpPostError
  | sslConnectError
  | badDownloadResume
  | fileCouldntReadFile
  | functionNotFound
  | abortedByCallback
  | badFunctionArgument
  | interfaceFailed
  | tooManyRedirects
  | unknownOption
  | gotNothing
  | sslEngineNotFound
  | sslEngineSetFailed
  | sendError
  | recvError
  | sslCertProblem
  | sslCipher
  | peerFailedVerification
  | badContentEncoding
  | loginDenied
  | noConnectionAvailable
  | sslPinnedpubkeynotmatch
  | sslInvalidcertstatus
  | http2Stream
  | recursiveApiCall
  | authError
  | http3
  | quicConnectError
  | proxyHandshake
  | unknown (code : UInt32)
  deriving Repr, BEq

namespace CurlCode

def fromNat (n : Nat) : CurlCode :=
  match n with
  | 0 => .ok
  | 1 => .unsupportedProtocol
  | 2 => .failedInit
  | 3 => .urlMalformat
  | 5 => .couldntResolveProxy
  | 6 => .couldntResolveHost
  | 7 => .couldntConnect
  | 8 => .weirdServerReply
  | 9 => .remoteAccessDenied
  | 10 => .ftpAcceptFailed
  | 12 => .ftpAcceptTimeout
  | 14 => .ftpBadPassword
  | 15 => .ftpCantGetHost
  | 22 => .httpReturnedError
  | 23 => .writeError
  | 25 => .uploadFailed
  | 26 => .readError
  | 27 => .outOfMemory
  | 28 => .operationTimedout
  | 33 => .rangeError
  | 34 => .httpPostError
  | 35 => .sslConnectError
  | 36 => .badDownloadResume
  | 37 => .fileCouldntReadFile
  | 41 => .functionNotFound
  | 42 => .abortedByCallback
  | 43 => .badFunctionArgument
  | 45 => .interfaceFailed
  | 47 => .tooManyRedirects
  | 48 => .unknownOption
  | 52 => .gotNothing
  | 53 => .sslEngineNotFound
  | 54 => .sslEngineSetFailed
  | 55 => .sendError
  | 56 => .recvError
  | 58 => .sslCertProblem
  | 59 => .sslCipher
  | 60 => .peerFailedVerification
  | 61 => .badContentEncoding
  | 67 => .loginDenied
  | 89 => .noConnectionAvailable
  | 90 => .sslPinnedpubkeynotmatch
  | 91 => .sslInvalidcertstatus
  | 92 => .http2Stream
  | 93 => .recursiveApiCall
  | 94 => .authError
  | 95 => .http3
  | 96 => .quicConnectError
  | 97 => .proxyHandshake
  | n => .unknown n.toUInt32

def toString : CurlCode → String
  | ok => "OK"
  | unsupportedProtocol => "Unsupported protocol"
  | failedInit => "Failed initialization"
  | urlMalformat => "URL malformed"
  | couldntResolveProxy => "Couldn't resolve proxy"
  | couldntResolveHost => "Couldn't resolve host"
  | couldntConnect => "Couldn't connect"
  | weirdServerReply => "Weird server reply"
  | remoteAccessDenied => "Remote access denied"
  | ftpAcceptFailed => "FTP accept failed"
  | ftpAcceptTimeout => "FTP accept timeout"
  | ftpBadPassword => "FTP bad password"
  | ftpCantGetHost => "FTP can't get host"
  | httpReturnedError => "HTTP returned error"
  | writeError => "Write error"
  | uploadFailed => "Upload failed"
  | readError => "Read error"
  | outOfMemory => "Out of memory"
  | operationTimedout => "Operation timed out"
  | rangeError => "Range error"
  | httpPostError => "HTTP POST error"
  | sslConnectError => "SSL connect error"
  | badDownloadResume => "Bad download resume"
  | fileCouldntReadFile => "File couldn't read file"
  | functionNotFound => "Function not found"
  | abortedByCallback => "Aborted by callback"
  | badFunctionArgument => "Bad function argument"
  | interfaceFailed => "Interface failed"
  | tooManyRedirects => "Too many redirects"
  | unknownOption => "Unknown option"
  | gotNothing => "Got nothing"
  | sslEngineNotFound => "SSL engine not found"
  | sslEngineSetFailed => "SSL engine set failed"
  | sendError => "Send error"
  | recvError => "Receive error"
  | sslCertProblem => "SSL certificate problem"
  | sslCipher => "SSL cipher error"
  | peerFailedVerification => "Peer failed verification"
  | badContentEncoding => "Bad content encoding"
  | loginDenied => "Login denied"
  | noConnectionAvailable => "No connection available"
  | sslPinnedpubkeynotmatch => "SSL pinned public key mismatch"
  | sslInvalidcertstatus => "SSL invalid certificate status"
  | http2Stream => "HTTP/2 stream error"
  | recursiveApiCall => "Recursive API call"
  | authError => "Authentication error"
  | http3 => "HTTP/3 error"
  | quicConnectError => "QUIC connect error"
  | proxyHandshake => "Proxy handshake error"
  | unknown code => s!"Unknown error ({code})"

instance : ToString CurlCode := ⟨toString⟩

end CurlCode

/-- Wisp error types -/
inductive WispError where
  | curlError (message : String)
  | httpError (status : UInt32) (message : String)
  | parseError (message : String)
  | timeoutError (message : String)
  | connectionError (message : String)
  | sslError (message : String)
  | ioError (message : String)
  deriving Repr

namespace WispError

def toString : WispError → String
  | curlError msg => s!"Curl error: {msg}"
  | httpError status msg => s!"HTTP error {status}: {msg}"
  | parseError msg => s!"Parse error: {msg}"
  | timeoutError msg => s!"Timeout: {msg}"
  | connectionError msg => s!"Connection error: {msg}"
  | sslError msg => s!"SSL error: {msg}"
  | ioError msg => s!"IO error: {msg}"

instance : ToString WispError := ⟨toString⟩

end WispError

/-- Result type for Wisp operations -/
abbrev WispResult (α : Type) := Except WispError α

end Wisp
