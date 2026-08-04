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

# Build FFMPEG for Android if FFMPEG_CORE_LOCAL_LIB_DIR is not already set.
# The ffmpeg-core CMake module expects static .a libs in <dir>/lib/.
if [ -z "${FFMPEG_CORE_LOCAL_LIB_DIR:-}" ]; then
    ffmpeg_out="$repo/out/ffmpeg-android-arm64"
    if [ ! -f "$ffmpeg_out/lib/libavcodec.a" ]; then
        echo "==> Building ffmpeg for Android arm64 (one-time, ~5 min)..."
        bash "$repo/tools/ci/build_ffmpeg_android.sh" "$ANDROID_NDK_HOME" "$ffmpeg_out"
    else
        echo "==> Reusing cached ffmpeg build: $ffmpeg_out/lib"
    fi
    export FFMPEG_CORE_LOCAL_LIB_DIR="$ffmpeg_out/lib"
fi
echo "==> Using FFMPEG_CORE_LOCAL_LIB_DIR=$FFMPEG_CORE_LOCAL_LIB_DIR"

cmake --preset android-release \
    -DFFMPEG_CORE_LOCAL_LIB_DIR="$FFMPEG_CORE_LOCAL_LIB_DIR" \
    -DMARATHON_RECOMP_OPTIMIZE_TOOLS=OFF
cmake --build "$build_dir" --target MarathonRecomp

so="$build_dir/MarathonRecomp/libmain.so"
if [ ! -f "$so" ]; then
    echo "ERROR: build finished but $so was not produced" >&2
    exit 1
fi

echo
echo "libmain.so built: $so"
