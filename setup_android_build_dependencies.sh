#!/usr/bin/env bash
# Installs the Android SDK components required by build_android_apk_replit.sh
# into this workspace. It does not require root access or modify the system.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
sdk_root="${ANDROID_SDK_ROOT:-$repo/.android-sdk}"
ndk_version="29.0.14206865"
cmdline_tools_url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

for command in curl unzip; do
    if ! command -v "$command" >/dev/null; then
        echo "ERROR: '$command' is required. Install it in the Replit environment, then run this script again." >&2
        exit 1
    fi
done

mkdir -p "$sdk_root/cmdline-tools"
sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"

if [ ! -x "$sdkmanager" ]; then
    archive="$(mktemp)"
    temp_dir="$(mktemp -d)"
    trap 'rm -f "$archive"; rm -rf "$temp_dir"' EXIT

    echo "==> Downloading Android SDK command-line tools"
    curl --fail --location --retry 3 --retry-delay 3 \
        --output "$archive" "$cmdline_tools_url"
    unzip -q "$archive" -d "$temp_dir"
    rm -rf "$sdk_root/cmdline-tools/latest"
    mv "$temp_dir/cmdline-tools" "$sdk_root/cmdline-tools/latest"
fi

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"

echo "==> Installing Android SDK platform, build tools, and NDK r29"
yes | "$sdkmanager" --sdk_root="$sdk_root" --licenses >/dev/null || true
"$sdkmanager" --sdk_root="$sdk_root" \
    "platform-tools" \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    "ndk;$ndk_version"

if [ ! -f "$sdk_root/ndk/$ndk_version/build/cmake/android.toolchain.cmake" ]; then
    echo "ERROR: Android NDK installation did not complete." >&2
    exit 1
fi

cat <<EOF

Android dependencies are ready.
For this shell, run:
  export ANDROID_SDK_ROOT="$sdk_root"
  export ANDROID_NDK_HOME="$sdk_root/ndk/$ndk_version"

The APK build script detects this workspace SDK automatically.
EOF