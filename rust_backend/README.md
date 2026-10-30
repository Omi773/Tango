# Tango Rust Backend

This directory contains Tango's Rust workspace. It provides shared backend
logic, provider clients, extension execution, the UniFFI mobile library, and
a separate C-ABI desktop library.

The workspace is defined in `Cargo.toml` and uses the pinned toolchain in
`rust-toolchain.toml`. It uses Rust edition 2024 and keeps its dependency
lockfile at `Cargo.lock`.

## Workspace crates

| Crate | Purpose |
| --- | --- |
| `tango-core` (`crates/core`) | Shared metadata, tags, filenames, covers, CUE sheets, lyrics, matching, Hi-Res analysis, and parsing helpers. |
| `tango-network` (`crates/network`) | Shared asynchronous HTTP transport, TLS, cookies, DNS, request policy, and URL handling. |
| `tango-providers` (`crates/providers`) | Provider integrations and shared lookup services, including Deezer, MusicBrainz, lyrics, and resolution. |
| `tango-extensions` (`crates/extensions`) | JavaScript extension runtime, manifests, package handling, host APIs, sessions, storage, and download services. |
| `tango-mobile` (`crates/mobile`) | UniFFI API and mobile backend functionality, including native library data, cache, collections, playlists, backup, lyrics, and network tags. |
| `tango-desktop` (`crates/desktop`) | C-ABI library for desktop integration through `dart:ffi`. |
| `tango-bindgen` (`crates/bindgen`) | UniFFI command-line tool used to generate Kotlin and Swift bindings. |

The dependency direction is intentional: core and network are foundational;
providers and extensions build on them; mobile and desktop expose backend
interfaces for their respective runtimes.

## Build scripts

Run commands from the repository root.

| Command | Purpose |
| --- | --- |
| `bash scripts/build_rust_backend.sh host` | Build the host mobile library and generate Kotlin and Swift UniFFI bindings. |
| `bash scripts/build_rust_backend.sh android` | Build the host artifacts and Android `tango-mobile` libraries. |
| `bash scripts/build_rust_backend.sh ios` | Build the iOS device and simulator libraries and stage the `TangoBackendFFI.xcframework` and CocoaPods files. |
| `bash scripts/build_rust_backend.sh desktop` | Build the desktop C-ABI library for the current macOS or Linux host. |
| `bash scripts/build_ios.sh` | Convenience wrapper for the iOS backend build. |

### Android build requirements

- Linux or macOS host.
- Android NDK 30.0.16248370, configured through `ANDROID_NDK_HOME`.
- By default, the script builds `arm64-v8a` and `armeabi-v7a`.
- Set `TANGO_RUST_ANDROID_ABIS` to one ABI or a comma-separated combination
  of those two supported ABIs to limit the build.

The script targets Android API 24 and configures 16 KB ELF page alignment.

### iOS build requirements

- macOS with Xcode and the Apple command-line tools.
- The script builds iOS device and simulator architectures and stages output
  under `rust_backend/target/ios/`.
- Run `cd ios && pod install` after the backend build when preparing the
  Flutter iOS project.

### Desktop build requirements

The desktop build script currently supports macOS (universal arm64/x86_64)
and Linux (native host architecture). It stages the library under
`rust_backend/target/desktop/`. This crate and build output do not, by
themselves, mean that Flutter runner projects for every desktop operating
system are present in this repository.

## Generated output

Build products are written under `rust_backend/target/` and are generated
locally or in CI; they are not source files to edit manually.

- `target/bindings/kotlin/` — generated Kotlin bindings.
- `target/bindings/swift/` — generated Swift bindings.
- `target/android/jniLibs/<abi>/` — Android shared libraries.
- `target/ios/` — iOS XCFramework and CocoaPods staging files.
- `target/desktop/<platform>/` — desktop C-ABI library.

After changing a UniFFI-exported API, rebuild the relevant target and update
its native call sites to match the generated interface.

## Vendored dependency patches

The workspace patches two crates.io dependencies with local copies:

- `rustix` — Android compatibility fallback for `statx` on older Android
  releases.
- `libusb1-sys` — updated bundled libusb native sources.

See [vendor/README.md](vendor/README.md) for the patch rationale, provenance,
and upgrade checks. Preserve the upstream license and notice files when
updating either vendored dependency.

## Testing and quality checks

Run these from the repository root:

```bash
cd rust_backend
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
```

For a focused crate test:

```bash
cd rust_backend
cargo test --locked -p tango-core
```

Use `--locked` so builds and tests respect the committed `Cargo.lock`.
