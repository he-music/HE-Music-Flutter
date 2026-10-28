# AudioTags

Read and write audio metadata in Flutter. Supports multiple formats.

## Usage

### Read

```dart
Tag? tag = await AudioTags.read(path);

String? title = tag?.title;
List<String>? artists = tag?.artists;
String? album = tag?.album;
List<String>? albumArtists = tag?.albumArtists;
String? genre = tag?.genre;
int? year = tag?.year;
int? trackNumber = tag?.trackNumber;
int? trackTotal = tag?.trackTotal;
int? discNumber = tag?.discNumber;
int? discTotal = tag?.discTotal;
int? duration = tag?.duration;
List<Picture>? pictures = tag?.pictures;
```

### Selective reads

`read(path)` remains a full read. Field groups can be selected before parsing
and before copying results over FFI:

```dart
// Tags + duration/bitrate/sample rate, without lyrics or embedded pictures.
final metadata = await AudioTags.read(path, options: AudioTagReadOptions.scan);

// Opt in to specific groups; all unspecified groups default to false.
final text = await AudioTags.read(
  path,
  options: const AudioTagReadOptions.only(tags: true, lyrics: true),
);

// A single preferred front cover, falling back to the first non-empty image.
// Audio properties are not calculated and text fields are not returned.
final cover = await AudioTags.readArtwork(path);
```

`AudioTagReadOptions.all` enables all groups. With the normal options constructor,
groups default to true, so `AudioTagReadOptions(pictures: false)` skips pictures
while preserving the other fields. Tags and lyrics still share the container's
parsing pass; selecting individual text fields would not avoid that pass. The
underlying Lofty 0.22 parser can skip cover-art parsing and audio-property work.
MP4 artwork does not retain front/back types, so its first image is used.
`readArtwork` returns null for a successful read with no artwork and throws on
I/O or parsing failure, allowing callers to cache absence separately from errors.

### Write

```dart
Tag tag = Tag(
    title: "Title",
    artists: ["Track Artist 1", "Track Artist 2"],
    album: "Album",
    albumArtists: ["Album Artist"],
    genre: "Genre",
    year: 2000,
    trackNumber: 1,
    trackTotal: 2,
    discNumber: 1,
    discTotal: 3,
    pictures: [
        Picture(
            bytes: Uint8List.fromList([0, 0, 0, 0]),
            mimeType: null,
            pictureType: PictureType.other
        )
    ]
);

AudioTags.write(path, tag);
```

## Supported Formats

This plugin uses a Rust crate called [`lofty`](https://github.com/Serial-ATA/lofty-rs) to write and read metadata.

The supported formats are listed [here](https://github.com/Serial-ATA/lofty-rs/blob/main/SUPPORTED_FORMATS.md).

## Development

This vendored copy is maintained as a standalone third-party library. If you change Rust sources or Flutter Rust Bridge bindings, you must regenerate the generated code and any checked-in native artifacts so Dart and native binaries stay on the same ABI.

### When You Need To Rebuild

Run the maintenance commands after changing any of these:

- `rust/src/**`
- `lib/src/rust/**`
- `flutter_rust_bridge.yaml`
- Rust structs used by FRB such as `Tag` or `Picture`

### Maintenance Commands

From `third_party/audiotags/`:

```bash
make codegen
make build-android
make build-macos
make build-ios
make build-linux
make build-windows
make build-windows-container  # macOS/Linux + Podman, no host Rust required
make regen
```

Command summary:

- `make codegen`
  Regenerates Flutter Rust Bridge Dart/Rust glue from `flutter_rust_bridge.yaml`.
- `make build-android`
  Rebuilds `android/src/main/jniLibs/*/libaudiotags.so` from the current Rust sources.
- `make build-macos`
  Rebuilds `macos/Libs/libaudiotags.a` as a universal macOS static library.
- `make build-ios`
  Rebuilds `ios/Frameworks/audiotags.xcframework` from the current Rust sources.
- `make build-linux`
  Rebuilds the checked-in Linux prebuilt library `linux/libaudiotags.so` on a Linux host.
- `make build-windows`
  Rebuilds the checked-in Windows prebuilt libraries in `windows/` on a Windows host.
- `make build-windows-container`
  Cross-compiles the Windows x64 MSVC DLL in a Podman container and checks its PE format, FRB exports, and binding hash before publishing the artifacts.
- `make regen`
  Runs codegen and then rebuilds Android, macOS, and iOS checked-in artifacts.

### Prerequisites

- `cargo`
- `flutter_rust_bridge_codegen`
- Android rebuild: Android SDK, Android NDK, Java, `rustup`
- macOS rebuild: Rust targets `aarch64-apple-darwin` and `x86_64-apple-darwin`
- iOS rebuild: Rust targets `aarch64-apple-ios`, `aarch64-apple-ios-sim`, and `x86_64-apple-ios`
- Linux validation build: Linux host with `cmake`
- Windows validation build: Windows host with `cmake`

Recommended setup:

```bash
rustup target add \
  aarch64-apple-darwin \
  x86_64-apple-darwin \
  aarch64-apple-ios \
  aarch64-apple-ios-sim \
  x86_64-apple-ios
```

Android rebuild notes:

- `make build-android` uses the vendored `cargokit` build tool directly.
- It writes fresh native libraries into `android/src/main/jniLibs/`.
- The main Flutter app and CI can keep consuming checked-in `jniLibs` without installing Rust Android build tooling on every pipeline run.
- You can override defaults if needed:

```bash
make build-android ANDROID_SDK_DIR=/path/to/sdk ANDROID_NDK_VERSION=28.2.13676358
```

iOS rebuild notes:

- `make build-ios` must run on macOS.
- It produces `ios/Frameworks/audiotags.xcframework`.

Linux and Windows notes:

- `make build-linux` must run on Linux.
- `make build-windows` must run on Windows.
- Both commands now refresh checked-in desktop prebuilt artifacts so consumers of this vendored library do not need Rust during normal app builds.

### Windows prebuilt library from macOS or Linux

Normal Flutter Windows builds consume `windows/audiotags.dll` through the plugin's
CMake configuration. Application users do **not** need Rust, cargo-xwin, or Podman.
The following tooling is only for maintainers refreshing the native library.

With Podman installed and its machine running, execute from this package root:

```sh
make build-windows-container
```

The build uses Rust 1.94.1 and cargo-xwin 0.23.1 in a Linux container, targets
`x86_64-pc-windows-msvc`, and links the C runtime statically. It works from an ARM64
host without running an x86 Windows container. Rust sources are mounted read-only;
Cargo compilation, crate downloads, and the MSVC SDK use separate named volumes.
The first build downloads the toolchain and SDK; later builds reuse those caches.

Outputs:

- `windows/audiotags.dll`: the runtime library bundled with the application.
- `windows/audiotags.dll.lib`: the MSVC import library, available for native linking.
- `windows/audiotags.build.json`: checksums, source fingerprint, compiler versions,
  imported DLLs, exported symbols, and static validation results.
- `build/windows-container/audiotags.inspection.txt`: detailed LLVM PE inspection
  output (not checked in).

The verifier checks the actual x64 constant-return machine code of
`frb_get_rust_content_hash` against both generated Rust and Dart binding hashes.
It also checks required FFI exports and rejects extra compiler runtime DLL
imports. These checks do **not** execute Windows code. Loading the library and
running the Flutter Windows application still require later Windows validation.
Only Windows x64 is covered by this prebuilt artifact.

Optional build configuration:

```sh
AUDIOTAGS_CONTAINER_ENGINE=podman \
AUDIOTAGS_PYPI_INDEX_URL=https://pypi.org/simple \
AUDIOTAGS_RUSTUP_DIST_SERVER=https://static.rust-lang.org \
AUDIOTAGS_DEBIAN_MIRROR=http://deb.debian.org/debian \
make build-windows-container
```

`AUDIOTAGS_WINDOWS_IMAGE` can override the local build-tool image name. These
variables configure maintenance tooling and do not change application settings.

### Why This Exists

This package currently checks in generated/native artifacts for some platforms. If you only regenerate Dart code but keep old native binaries, Flutter can end up calling a stale library with a new FRB layout, which causes runtime decode crashes.
