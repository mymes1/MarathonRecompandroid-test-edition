---
name: Android APK packaging checks
description: Packaging behavior and validation rules for this project's Android native APK builds.
---

Gradle strips the native library while packaging the debug APK, so the library extracted from the APK is not expected to be byte-identical to the unstripped CMake output. The staged `jniLibs` copy should match the CMake output exactly; validate the packaged file by ELF ABI/header and APK signature instead.

**Why:** A byte-for-byte APK comparison falsely reported stale native code even though the staged library matched the build and Gradle had only removed symbols.

**How to apply:** Build through `build_android_apk_replit.sh`, compare CMake output with `android-apk/app/src/main/jniLibs/arm64-v8a/libmain.so`, then inspect the APK's extracted library with `readelf` and verify it with the installed `apksigner`.