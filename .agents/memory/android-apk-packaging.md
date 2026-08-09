---
name: Android APK packaging checks
description: Packaging behavior and validation rules for this project's Android native APK builds.
---

Gradle strips the native library while packaging the debug APK, so the library extracted from the APK is not expected to be byte-identical to the unstripped CMake output. The staged `jniLibs` copy should match the CMake output exactly; validate the packaged file by ELF ABI/header and APK signature instead.

The one-command Android build must export the workspace SDK path independently of NDK discovery when `.android-sdk/platforms/android-35/android.jar` is present.

**Why:** A byte-for-byte APK comparison falsely reported stale native code even though the staged library matched the build and Gradle had only removed symbols.

**How to apply:** Before invoking Gradle, set both SDK variables to the workspace SDK when the compile platform is present, while preserving caller-supplied SDK variables. Build through `build_android_apk_replit.sh`, compare CMake output with `android-apk/app/src/main/jniLibs/arm64-v8a/libmain.so`, then inspect the APK's extracted library with `readelf` and verify it with the installed `apksigner`.

## Build duration

Clean Android builds compile hundreds of generated arm64 translation units and can outlive a single shell invocation even when compilation is progressing normally. The configured Android workflow resumes from its existing CMake/Ninja state; do not interpret a shell timeout alone as a compiler failure.

**Why:** A clean rebuild exceeded the command timeout while active compilers were still making progress, and the resumed workflow completed successfully without code changes.

**How to apply:** Check for active `ninja`/compiler processes and the Android build log before retrying. Resume the configured workflow or rerun incrementally instead of deleting the build tree again.