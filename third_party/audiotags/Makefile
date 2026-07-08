SHELL := /bin/bash

.PHONY: help codegen build-android build-macos build-ios build-linux build-windows regen \
	check-build-tool check-macos-targets check-macos-host check-ios-targets check-linux-host check-windows-host

RUST_MANIFEST := rust/Cargo.toml
ANDROID_JNILIBS_DIR := android/src/main/jniLibs
ANDROID_BUILD_OUTPUT_DIR := build/android-jniLibs
ANDROID_TARGET_TEMP_DIR := build/android-target
ANDROID_TOOL_TEMP_DIR := build/android-tool
ANDROID_SDK_DIR ?= $(HOME)/Library/Android/sdk
ANDROID_NDK_VERSION ?= $(shell ls "$(ANDROID_SDK_DIR)/ndk" 2>/dev/null | sort -V | tail -n 1)
ANDROID_COMPILE_SDK_VERSION ?= 35
ANDROID_MIN_SDK_VERSION ?= 21
ANDROID_TARGET_PLATFORMS ?= android-arm,android-arm64,android-x86,android-x64
JAVA_HOME ?= $(shell /usr/libexec/java_home 2>/dev/null)
RUN_BUILD_TOOL := $(abspath rust_builder/cargokit/run_build_tool.sh)
RUN_BUILD_TOOL_CMD := $(abspath rust_builder/cargokit/run_build_tool.cmd)
MACOS_LIB_DIR := macos/Libs
MACOS_ARM64_LIB := rust/target/aarch64-apple-darwin/release/libaudiotags.a
MACOS_X64_LIB := rust/target/x86_64-apple-darwin/release/libaudiotags.a
IOS_FRAMEWORK_DIR := ios/Frameworks
IOS_XCFRAMEWORK_DIR := $(IOS_FRAMEWORK_DIR)/audiotags.xcframework
IOS_DEVICE_LIB := rust/target/aarch64-apple-ios/release/libaudiotags.a
IOS_SIM_ARM64_LIB := rust/target/aarch64-apple-ios-sim/release/libaudiotags.a
IOS_SIM_X64_LIB := rust/target/x86_64-apple-ios/release/libaudiotags.a
IOS_SIM_UNIVERSAL_LIB := build/ios-simulator/libaudiotags.a

help:
	@echo "audiotags maintenance commands"
	@echo "  make codegen        # Regenerate Flutter Rust Bridge Dart/Rust bindings"
	@echo "  make build-android  # Rebuild Android jniLibs/*.so from current Rust sources"
	@echo "  make build-macos    # Rebuild macOS universal static library"
	@echo "  make build-ios      # Rebuild iOS xcframework from current Rust sources"
	@echo "  make build-linux    # Validate a Linux Rust plugin build on a Linux host"
	@echo "  make build-windows  # Validate a Windows Rust plugin build on a Windows host"
	@echo "  make regen          # Run codegen + rebuild Android, macOS, and iOS artifacts"

codegen:
	flutter_rust_bridge_codegen generate --config-file flutter_rust_bridge.yaml

check-build-tool:
	@command -v cargo >/dev/null 2>&1 || { echo "cargo is required"; exit 1; }
	@command -v rustup >/dev/null 2>&1 || { echo "rustup is required"; exit 1; }
	@test -x "$(RUN_BUILD_TOOL)" || { echo "Missing build tool: $(RUN_BUILD_TOOL)"; exit 1; }
	@test -n "$(ANDROID_NDK_VERSION)" || { echo "ANDROID_NDK_VERSION is required"; exit 1; }
	@test -d "$(ANDROID_SDK_DIR)" || { echo "ANDROID_SDK_DIR does not exist: $(ANDROID_SDK_DIR)"; exit 1; }
	@test -n "$(JAVA_HOME)" || { echo "JAVA_HOME is required"; exit 1; }

build-android: check-build-tool
	rm -rf "$(ANDROID_BUILD_OUTPUT_DIR)" "$(ANDROID_TARGET_TEMP_DIR)"
	mkdir -p "$(ANDROID_BUILD_OUTPUT_DIR)" "$(ANDROID_TARGET_TEMP_DIR)" "$(ANDROID_TOOL_TEMP_DIR)" "$(ANDROID_JNILIBS_DIR)"
	CARGOKIT_ROOT_PROJECT_DIR="$(CURDIR)" \
	CARGOKIT_TOOL_TEMP_DIR="$(CURDIR)/$(ANDROID_TOOL_TEMP_DIR)" \
	CARGOKIT_MANIFEST_DIR="$(CURDIR)/rust" \
	CARGOKIT_CONFIGURATION=release \
	CARGOKIT_TARGET_TEMP_DIR="$(CURDIR)/$(ANDROID_TARGET_TEMP_DIR)" \
	CARGOKIT_OUTPUT_DIR="$(CURDIR)/$(ANDROID_BUILD_OUTPUT_DIR)" \
	CARGOKIT_NDK_VERSION="$(ANDROID_NDK_VERSION)" \
	CARGOKIT_SDK_DIR="$(ANDROID_SDK_DIR)" \
	CARGOKIT_COMPILE_SDK_VERSION="$(ANDROID_COMPILE_SDK_VERSION)" \
	CARGOKIT_MIN_SDK_VERSION="$(ANDROID_MIN_SDK_VERSION)" \
	CARGOKIT_TARGET_PLATFORMS="$(ANDROID_TARGET_PLATFORMS)" \
	CARGOKIT_JAVA_HOME="$(JAVA_HOME)" \
	"$(RUN_BUILD_TOOL)" build-gradle
	mkdir -p "$(ANDROID_JNILIBS_DIR)"
	cp -R "$(ANDROID_BUILD_OUTPUT_DIR)"/. "$(ANDROID_JNILIBS_DIR)/"

check-macos-targets:
	@rustup target list --installed | grep -q '^aarch64-apple-darwin$$' || { echo "Missing rust target: aarch64-apple-darwin"; exit 1; }
	@rustup target list --installed | grep -q '^x86_64-apple-darwin$$' || { echo "Missing rust target: x86_64-apple-darwin"; exit 1; }
	@command -v lipo >/dev/null 2>&1 || { echo "lipo is required on macOS"; exit 1; }

check-macos-host:
	@[ "$$(uname -s)" = "Darwin" ] || { echo "This target must run on macOS"; exit 1; }

build-macos: check-macos-targets
	cargo build --manifest-path "$(RUST_MANIFEST)" --release --target aarch64-apple-darwin
	cargo build --manifest-path "$(RUST_MANIFEST)" --release --target x86_64-apple-darwin
	mkdir -p "$(MACOS_LIB_DIR)"
	lipo -create "$(MACOS_ARM64_LIB)" "$(MACOS_X64_LIB)" -output "$(MACOS_LIB_DIR)/libaudiotags.a"

check-ios-targets: check-macos-host
	@rustup target list --installed | grep -q '^aarch64-apple-ios$$' || { echo "Missing rust target: aarch64-apple-ios"; exit 1; }
	@rustup target list --installed | grep -q '^aarch64-apple-ios-sim$$' || { echo "Missing rust target: aarch64-apple-ios-sim"; exit 1; }
	@rustup target list --installed | grep -q '^x86_64-apple-ios$$' || { echo "Missing rust target: x86_64-apple-ios"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is required on macOS"; exit 1; }
	@command -v lipo >/dev/null 2>&1 || { echo "lipo is required on macOS"; exit 1; }

build-ios: check-ios-targets
	cargo build --manifest-path "$(RUST_MANIFEST)" --release --target aarch64-apple-ios
	cargo build --manifest-path "$(RUST_MANIFEST)" --release --target aarch64-apple-ios-sim
	cargo build --manifest-path "$(RUST_MANIFEST)" --release --target x86_64-apple-ios
	mkdir -p "$$(dirname "$(IOS_SIM_UNIVERSAL_LIB)")" "$(IOS_FRAMEWORK_DIR)"
	lipo -create "$(IOS_SIM_ARM64_LIB)" "$(IOS_SIM_X64_LIB)" -output "$(IOS_SIM_UNIVERSAL_LIB)"
	rm -rf "$(IOS_XCFRAMEWORK_DIR)"
	xcodebuild -create-xcframework \
		-library "$(IOS_DEVICE_LIB)" \
		-library "$(IOS_SIM_UNIVERSAL_LIB)" \
		-output "$(IOS_XCFRAMEWORK_DIR)"

check-linux-host:
	@[ "$$(uname -s)" = "Linux" ] || { echo "This target must run on Linux"; exit 1; }
	@command -v cmake >/dev/null 2>&1 || { echo "cmake is required"; exit 1; }
	@command -v cargo >/dev/null 2>&1 || { echo "cargo is required"; exit 1; }
	@command -v rustup >/dev/null 2>&1 || { echo "rustup is required"; exit 1; }

build-linux: check-linux-host
	rm -rf build/linux-target
	mkdir -p build/linux-target linux
	CARGOKIT_ROOT_PROJECT_DIR="$(CURDIR)" \
	CARGOKIT_TOOL_TEMP_DIR="$(CURDIR)/build/linux-tool" \
	CARGOKIT_MANIFEST_DIR="$(CURDIR)/rust" \
	CARGOKIT_CONFIGURATION=release \
	CARGOKIT_TARGET_TEMP_DIR="$(CURDIR)/build/linux-target" \
	CARGOKIT_OUTPUT_DIR="$(CURDIR)/linux" \
	CARGOKIT_TARGET_PLATFORM=linux-x64 \
	"$(RUN_BUILD_TOOL)" build-cmake

check-windows-host:
	@if [ -n "$$OS" ] && [ "$$OS" = "Windows_NT" ]; then exit 0; fi; \
	echo "This target must run on Windows"; exit 1

build-windows: check-windows-host
	if not exist build\\windows-target mkdir build\\windows-target
	if not exist windows mkdir windows
	set CARGOKIT_ROOT_PROJECT_DIR=$(CURDIR) && \
	set CARGOKIT_TOOL_TEMP_DIR=$(CURDIR)\\build\\windows-tool && \
	set CARGOKIT_MANIFEST_DIR=$(CURDIR)\\rust && \
	set CARGOKIT_CONFIGURATION=release && \
	set CARGOKIT_TARGET_TEMP_DIR=$(CURDIR)\\build\\windows-target && \
	set CARGOKIT_OUTPUT_DIR=$(CURDIR)\\windows && \
	set CARGOKIT_TARGET_PLATFORM=windows-x64 && \
	cmd //c "$(RUN_BUILD_TOOL_CMD) build-cmake"

regen: codegen build-android build-macos build-ios build-windows build-linux
