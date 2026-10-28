#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
engine="${AUDIOTAGS_CONTAINER_ENGINE:-podman}"
image="${AUDIOTAGS_WINDOWS_IMAGE:-localhost/he-music-audiotags-windows:rust1.94.1-xwin0.23.1}"

command -v "$engine" >/dev/null || { printf '%s is required\n' "$engine" >&2; exit 1; }
"$engine" info >/dev/null

build_args=("$engine" build)
if [[ -n "${AUDIOTAGS_PYPI_INDEX_URL:-}" ]]; then
  build_args+=(--build-arg "PIP_INDEX_URL=$AUDIOTAGS_PYPI_INDEX_URL")
fi
if [[ -n "${AUDIOTAGS_RUSTUP_DIST_SERVER:-}" ]]; then
  build_args+=(--build-arg "RUSTUP_DIST_SERVER=$AUDIOTAGS_RUSTUP_DIST_SERVER")
fi
if [[ -n "${AUDIOTAGS_DEBIAN_MIRROR:-}" ]]; then
  build_args+=(--build-arg "DEBIAN_MIRROR=$AUDIOTAGS_DEBIAN_MIRROR")
fi

"${build_args[@]}" \
  --file "$package_dir/scripts/windows/Containerfile" \
  --tag "$image" "$package_dir/scripts/windows"

mkdir -p "$package_dir/build/windows-container" "$package_dir/windows"
"$engine" run --rm --security-opt label=disable \
  --volume "$package_dir:/work:ro" \
  --volume "$package_dir/windows:/output" \
  --volume "$package_dir/build/windows-container:/inspection" \
  --volume he-music-audiotags-windows-registry:/usr/local/cargo/registry \
  --volume he-music-audiotags-windows-sdk:/xwin-cache \
  --volume he-music-audiotags-windows-target:/target \
  "$image" bash -euo pipefail -c '
    cargo xwin build --locked --release \
      --manifest-path rust/Cargo.toml --target x86_64-pc-windows-msvc
    dll=/target/x86_64-pc-windows-msvc/release/audiotags.dll
    import_lib=/target/x86_64-pc-windows-msvc/release/audiotags.dll.lib
    test -s "$dll"
    test -s "$import_lib"
    python3 scripts/verify_windows_library.py "$dll" \
      --package-dir /work --report /inspection/audiotags.build.json
    llvm-readobj --file-headers --coff-exports --coff-imports "$dll" \
      > /inspection/audiotags.inspection.txt
    cp "$dll" /output/audiotags.dll.tmp
    cp "$import_lib" /output/audiotags.dll.lib.tmp
    mv /output/audiotags.dll.tmp /output/audiotags.dll
    mv /output/audiotags.dll.lib.tmp /output/audiotags.dll.lib
    cp /inspection/audiotags.build.json /output/audiotags.build.json
  '
chmod 644 "$package_dir/windows/audiotags.dll" \
  "$package_dir/windows/audiotags.dll.lib" "$package_dir/windows/audiotags.build.json"
printf 'Windows x64 artifacts: %s/windows/audiotags.dll{,.lib}\n' "$package_dir"
