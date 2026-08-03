#!/usr/bin/env bash
# Cross-compiles libmain.so (the whole game) for Android (arm64-v8a) using the NDK.
#
# Requirements:
#   - ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) pointing at NDK r29 (29.0.14206865)
#   - Host tools already built: run ./build_host_tools.sh first
#   - MarathonRecompLib/private/default.xex + shader.arc + shader_lt.arc in place
#     (legally acquired game files)
#   - On the first run the CMake step may need to fetch vcpkg packages; the
#     android release path itself uses the NDK toolchain directly.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
build_dir="$repo/out/build/android-arm64"

if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -n "${ANDROID_NDK_ROOT:-}" ]; then
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
fi
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "ERROR: ANDROID_NDK_HOME must point to NDK r29 (e.g. \$HOME/Android/Sdk/ndk/29.0.14206865)" >&2
    exit 1
fi

cmake --preset android-release
cmake --build "$build_dir" --target MarathonRecomp

so="$build_dir/MarathonRecomp/libmain.so"
if [ ! -f "$so" ]; then
    echo "ERROR: build finished but $so was not produced" >&2
    exit 1
fi

echo
echo "libmain.so built: $so"
