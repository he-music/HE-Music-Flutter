#!/usr/bin/env python3
"""Inspect a cross-built PE DLL without claiming Windows runtime validation."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

import pefile


def version(*command):
    return subprocess.check_output(command, text=True).strip()


def inspect(dll, package_dir):
    image = pefile.PE(str(dll))
    if image.FILE_HEADER.Machine != 0x8664 or image.OPTIONAL_HEADER.Magic != 0x20B:
        raise ValueError("Expected a Windows x64 PE32+ library")
    if not image.FILE_HEADER.Characteristics & 0x2000:
        raise ValueError("PE file is not marked as a DLL")

    exports = {
        symbol.name.decode("ascii"): symbol
        for symbol in image.DIRECTORY_ENTRY_EXPORT.symbols
        if symbol.name
    }
    required = {
        "frb_get_rust_content_hash",
        "frb_init_frb_dart_api_dl",
        "frb_pde_ffi_dispatcher_primary",
        "frb_pde_ffi_dispatcher_sync",
        "frb_rust_vec_u8_new",
        "frb_rust_vec_u8_free",
    }
    if missing := required - exports.keys():
        raise ValueError(f"Missing FRB exports: {sorted(missing)}")

    rust_bindings = package_dir / "rust/src/frb_generated.rs"
    dart_bindings = package_dir / "lib/src/rust/frb_generated.dart"
    rust_hash = int(re.search(
        r"FLUTTER_RUST_BRIDGE_CODEGEN_CONTENT_HASH:\s*i32\s*=\s*(-?\d+)",
        rust_bindings.read_text(),
    ).group(1))
    dart_hash = int(re.search(
        r"rustContentHash\s*=>\s*(-?\d+)", dart_bindings.read_text(),
    ).group(1))
    if rust_hash != dart_hash:
        raise ValueError("Dart and Rust generated binding hashes differ")

    # The pinned x64 release toolchain emits this leaf constant-return function
    # as MOV EAX, imm32; RET. Fail closed if that changes instead of assuming a
    # DLL's exported symbol name proves its bridge layout matches the Dart side.
    function = exports["frb_get_rust_content_hash"]
    code = image.get_data(function.address, 6)
    if function.forwarder or len(code) != 6 or code[0] != 0xB8 or code[5] != 0xC3:
        raise ValueError("Unrecognized FRB hash function; inspect its disassembly")
    binary_hash = struct.unpack("<i", code[1:5])[0]
    if binary_hash != rust_hash:
        raise ValueError(f"DLL bridge hash {binary_hash} does not match {rust_hash}")

    imports = sorted(entry.dll.decode("ascii") for entry in image.DIRECTORY_ENTRY_IMPORT)
    if any(name.lower().startswith(("vcruntime", "msvcp", "libgcc", "libwinpthread")) for name in imports):
        raise ValueError("Unexpected external compiler runtime dependency")

    source_hash = hashlib.sha256()
    sources = [package_dir / "rust/Cargo.toml", package_dir / "rust/Cargo.lock"]
    sources += sorted((package_dir / "rust/src").rglob("*.rs"))
    for source in sources:
        source_hash.update(str(source.relative_to(package_dir)).encode())
        source_hash.update(b"\0")
        source_hash.update(source.read_bytes())

    return {
        "target": "x86_64-pc-windows-msvc",
        "format": "PE32+ DLL (AMD64)",
        "sha256": hashlib.sha256(dll.read_bytes()).hexdigest(),
        "rust_source_sha256": source_hash.hexdigest(),
        "frb_content_hash": binary_hash,
        "rustc": version("rustc", "--version"),
        "cargo_xwin": version("cargo-xwin", "--version"),
        "crt": "static",
        "imports": imports,
        "exports": sorted(exports),
        "validation": "Static PE inspection; not executed on Windows",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dll", type=Path)
    parser.add_argument("--package-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = inspect(args.dll, args.package_dir)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Verified {report['format']}; FRB hash={report['frb_content_hash']}; SHA256={report['sha256']}")


if __name__ == "__main__":
    main()
