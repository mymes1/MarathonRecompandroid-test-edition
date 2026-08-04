# Marathon Recomp

## Project overview

Marathon Recomp is a C++ recompilation project with an Android APK target. The Android renderer uses Vulkan and includes device-specific compatibility paths for unstable vendor drivers.

## Android build

Run `./build_android_apk_replit.sh` to build host tools, compile the Android arm64-v8a native libraries, and package the debug APK. It requires Android NDK r29, the Android SDK/JDK, and the game files in `MarathonRecompLib/private`.

## User preferences

No saved preferences yet.