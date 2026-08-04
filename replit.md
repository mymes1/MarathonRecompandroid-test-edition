# Marathon Recomp

## Project overview

Marathon Recomp is a C++ recompilation project with an Android APK target. The Android renderer uses Vulkan and includes device-specific compatibility paths for unstable vendor drivers.

## Android build

Run `./setup_android_build_dependencies.sh` to install the Android SDK, API 34 build tools, and NDK r29 into `.android-sdk/`. Then run `./build_android_apk_replit.sh` to build host tools, compile the Android arm64-v8a native libraries, and package the debug APK. The build script runs setup automatically if the workspace NDK is missing. Both commands require the game files in `MarathonRecompLib/private`.

## User preferences

No saved preferences yet.