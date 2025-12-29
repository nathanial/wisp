import Lake
open Lake DSL System

package wisp where
  precompileModules := true

require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.1"
require staple from git "https://github.com/nathanial/staple" @ "v0.0.1"

-- Platform-specific curl library paths
-- On macOS, curl may be in various locations:
-- - /opt/homebrew/opt/curl (Homebrew keg-only curl with WebSocket support)
-- - /opt/homebrew/lib (Homebrew Apple Silicon)
-- - /usr/local/lib (Homebrew Intel)
-- - /opt/homebrew/anaconda3/lib (Anaconda)
-- - System curl (via -lcurl with SDK paths)
-- NOTE: Homebrew curl 8.11+ required for WebSocket support (ws:// and wss://)
def curlLinkArgs : Array String :=
  if Platform.isOSX then
    #["-L/opt/homebrew/opt/curl/lib",  -- Homebrew keg-only curl (WebSocket support)
      "-L/opt/homebrew/lib",
      "-L/usr/local/lib",
      "-L/opt/homebrew/anaconda3/lib",
      "-lcurl",
      -- Add rpath so dylibs can find libcurl at runtime
      "-Wl,-rpath,/opt/homebrew/opt/curl/lib",
      "-Wl,-rpath,/opt/homebrew/lib",
      "-Wl,-rpath,/opt/homebrew/anaconda3/lib",
      "-Wl,-rpath,/usr/local/lib"]
  else if Platform.isWindows then
    #["-lcurl"]
  else
    -- Linux: system curl
    #["-lcurl", "-Wl,-rpath,/usr/lib", "-Wl,-rpath,/usr/local/lib"]

def curlIncludeArgs : Array String :=
  if Platform.isOSX then
    #["-I/opt/homebrew/opt/curl/include",  -- Homebrew keg-only curl (WebSocket support)
      "-I/opt/homebrew/include",
      "-I/usr/local/include",
      "-I/opt/homebrew/anaconda3/include"]
  else
    #[]

@[default_target]
lean_lib Wisp where
  roots := #[`Wisp]
  moreLinkArgs := curlLinkArgs

lean_lib WispTests where
  roots := #[`WispTests]

@[test_driver]
lean_exe wisp_tests where
  root := `WispTests.Main
  moreLinkArgs := curlLinkArgs

lean_exe simple_get where
  root := `examples.SimpleGet
  moreLinkArgs := curlLinkArgs

lean_exe post_json where
  root := `examples.PostJSON
  moreLinkArgs := curlLinkArgs

lean_exe minimal_test where
  root := `examples.MinimalTest
  moreLinkArgs := curlLinkArgs

lean_exe client_test where
  root := `examples.ClientTest
  moreLinkArgs := curlLinkArgs

-- FFI: Build C code
target wisp_ffi_o pkg : FilePath := do
  let oFile := pkg.buildDir / "native" / "wisp_ffi.o"
  let srcJob ← inputTextFile <| pkg.dir / "native" / "src" / "wisp_ffi.c"
  let leanIncludeDir ← getLeanIncludeDir
  let weakArgs := #["-I", leanIncludeDir.toString,
                    "-I", (pkg.dir / "native" / "include").toString] ++ curlIncludeArgs
  buildO oFile srcJob weakArgs #["-fPIC", "-O2"] "cc" getLeanTrace

extern_lib wisp_native pkg := do
  let name := nameToStaticLib "wisp_native"
  let ffiO ← wisp_ffi_o.fetch
  buildStaticLib (pkg.buildDir / "lib" / name) #[ffiO]
