#!/usr/bin/env bash
# Builds the debug APK. Copies the freshly built libmain.so from the CMake tree
# into jniLibs first (the gradle project deliberately has no dependency on the
# CMake build; see android-apk/app/build.gradle), then runs gradle assembleDebug.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
so="$repo/out/build/android-arm64/MarathonRecomp/libmain.so"
jni="$repo/android-apk/app/src/main/jniLibs/arm64-v8a"

mkdir -p "$jni"
# Do not leave stale adrenotools hooks beside a newly built native library.
# The Android driver loader opens these from nativeLibraryDir.
rm -f "$jni"/libmain_hook.so "$jni"/libfile_redirect_hook.so \
      "$jni"/libgsl_alloc_hook.so "$jni"/libhook_impl.so

if [ -f "$so" ]; then
    cp -f "$so" "$jni/libmain.so"
    echo "Copied $so -> $jni/libmain.so"
else
    echo "WARNING: no freshly built libmain.so in out/build/android-arm64, packaging the existing jniLibs copy." >&2
fi

# CMake places these hooks next to libmain.so. Package the fresh copies when
# present; stale copies were removed above so a missing hook cannot be hidden.
for hook in main_hook file_redirect_hook gsl_alloc_hook hook_impl; do
    hook_so="$repo/out/build/android-arm64/MarathonRecomp/lib${hook}.so"
    if [ -f "$hook_so" ]; then
        cp -f "$hook_so" "$jni/lib${hook}.so"
        echo "Copied $hook_so -> $jni/lib${hook}.so"
    fi
done

cd "$repo/android-apk"
# The native library is copied into jniLibs by this script rather than being a
# Gradle/CMake dependency.  Gradle can therefore incorrectly mark
# mergeDebugNativeLibs UP-TO-DATE and package an older libmain.so.  Clean the
# generated packaging intermediates so the APK always contains the library
# built immediately above.
./gradlew clean assembleDebug --no-build-cache --no-daemon

apk="$repo/android-apk/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -f "$apk" ]; then
    echo "ERROR: Gradle completed but did not produce $apk." >&2
    exit 1
fi

# Verify the native payload before an APK is installed on the tablet.
for native_so in libmain.so libmain_hook.so libfile_redirect_hook.so libgsl_alloc_hook.so libhook_impl.so; do
    if ! unzip -l "$apk" "lib/arm64-v8a/$native_so" | grep -q "lib/arm64-v8a/$native_so"; then
        echo "ERROR: APK is missing lib/arm64-v8a/$native_so." >&2
        exit 1
    fi
done
