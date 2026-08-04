#!/usr/bin/env bash
# Replit one-command Android build:
#   1. Build the host code-generation tools.
#   2. Build ffmpeg static libraries for arm64-android (one-time, cached in out/ffmpeg-android-arm64).
#   3. Cross-compile the arm64-v8a native libraries.
#   4. Package those libraries into a debug APK.
#
# Required:
#   - ANDROID_NDK_HOME pointing to Android NDK r29 (29.0.14206865)
#   - JDK 17+ (17, 19, 21 all work) and Android SDK (compileSdk 35)
#   - MarathonRecompLib/private/default.xex, shader.arc, shader_lt.arc
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
workspace_sdk="$repo/.android-sdk"
ndk_version="29.0.14206865"

if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -n "${ANDROID_NDK_ROOT:-}" ]; then
    export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] && [ -f "$workspace_sdk/ndk/$ndk_version/build/cmake/android.toolchain.cmake" ]; then
    export ANDROID_SDK_ROOT="$workspace_sdk"
    export ANDROID_HOME="$workspace_sdk"
    export ANDROID_NDK_HOME="$workspace_sdk/ndk/$ndk_version"
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]; then
    echo "==> Android NDK not found; installing Android build dependencies"
    "$repo/setup_android_build_dependencies.sh"
    export ANDROID_SDK_ROOT="$workspace_sdk"
    export ANDROID_HOME="$workspace_sdk"
    export ANDROID_NDK_HOME="$workspace_sdk/ndk/$ndk_version"
fi

for required_file in default.xex shader.arc shader_lt.arc; do
    if [ ! -f "$repo/MarathonRecompLib/private/$required_file" ]; then
        echo "ERROR: Missing MarathonRecompLib/private/$required_file." >&2
        exit 1
    fi
done

if ! command -v cmake >/dev/null || ! command -v ninja >/dev/null; then
    echo "ERROR: cmake and ninja must be installed." >&2
    exit 1
fi

if ! command -v java >/dev/null; then
    echo "ERROR: A JDK is required to package the APK." >&2
    exit 1
fi

export VCPKG_ROOT="${VCPKG_ROOT:-$repo/thirdparty/vcpkg}"

# Replit's Nix pkg-config wrapper does not resolve a package while vcpkg is
# rewriting that package's .pc file. The local libpng overlay keeps the normal
# port and skips only that nonessential post-install validation.
export VCPKG_DISABLE_METRICS=1

# In the Replit/NixOS environment the system zlib lives inside the Nix store
# rather than a standard /usr/lib path, so the dynamic linker cannot find
# libz.so.1 when the host tools (XenosRecomp, XenonRecomp) are executed during
# the Android cross-compile step.  Resolve the library directory from
# pkg-config and prepend it to LD_LIBRARY_PATH.
if command -v pkg-config >/dev/null && pkg-config --exists zlib 2>/dev/null; then
    _zlib_libdir="$(pkg-config --libs-only-L zlib | sed 's/-L//g' | xargs)"
    if [ -n "$_zlib_libdir" ]; then
        export LD_LIBRARY_PATH="${_zlib_libdir}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        echo "==> Added zlib to LD_LIBRARY_PATH: $_zlib_libdir"
    fi
    unset _zlib_libdir
fi

echo "==> Building host code-generation tools"
"$repo/build_host_tools.sh"

echo "==> Building Android arm64-v8a native libraries"
"$repo/build_android.sh"

echo "==> Packaging native libraries into the debug APK"
"$repo/build_apk.sh"

apk="$repo/android-apk/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$apk" ]; then
    echo "ERROR: Gradle completed but did not produce $apk." >&2
    exit 1
fi

echo
echo "Build complete:"
echo "  Native library: $repo/out/build/android-arm64/MarathonRecomp/libmain.so"
echo "  Debug APK:      $apk"