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

### Why This Exists

This package currently checks in generated/native artifacts for some platforms. If you only regenerate Dart code but keep old native binaries, Flutter can end up calling a stale library with a new FRB layout, which causes runtime decode crashes.
