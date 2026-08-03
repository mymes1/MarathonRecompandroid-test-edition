#!/usr/bin/env bash
# Builds the debug APK. Copies the freshly built libmain.so from the CMake tree
# into jniLibs first (the gradle project deliberately has no dependency on the
# CMake build; see android-apk/app/build.gradle), then runs gradle assembleDebug.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
so="$repo/out/build/android-arm64/MarathonRecomp/libmain.so"
jni="$repo/android-apk/app/src/main/jniLibs/arm64-v8a"

if [ -f "$so" ]; then
    mkdir -p "$jni"
    cp -f "$so" "$jni/libmain.so"
    echo "Copied $so -> $jni/libmain.so"
else
    echo "WARNING: no freshly built libmain.so in out/build/android-arm64, packaging the existing jniLibs copy." >&2
fi

cd "$repo/android-apk"
./gradlew assembleDebug
