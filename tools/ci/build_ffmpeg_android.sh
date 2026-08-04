#!/usr/bin/env bash
# Builds the static ffmpeg libraries (7.1.1 + the xmaframes XMA decoder patch
# used by MarathonRecomp's audio) for arm64-android using the NDK.
#
# Usage: build_ffmpeg_android.sh <ndk-root> <output-dir> [ffmpeg-source-tar]
#
# Everything is downloaded and built automatically. The output dir receives the
# six static libs in the layout ffmpeg-core's CMake expects (lib/*.a), ready to
# be passed to CMake as -DFFMPEG_CORE_LOCAL_LIB_DIR=<output-dir>/lib.
set -euo pipefail

ndk="${1:?usage: build_ffmpeg_android.sh <ndk-root> <output-dir> [source-tar]}"
outdir="${2:?usage: build_ffmpeg_android.sh <ndk-root> <output-dir> [source-tar]}"

FFMPEG_VERSION="7.1.1"
FFMPEG_SHA512="6b9a5ee501be41d6abc7579a106263b31f787321cbc45dedee97abf992bf8236cdb2394571dd256a74154f4a20018d429ae7e7f0409611ddc4d6f529d924d175"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH="$SCRIPT_DIR/0008-xmaframes.patch"

toolchain="$ndk/toolchains/llvm/prebuilt/linux-x86_64"
sysroot="$toolchain/sysroot"
bin="$toolchain/bin"
api="29"

work="$outdir/.work"
mkdir -p "$work" "$outdir/lib"

# Always rebuild from scratch: a previous run may have produced non-PIC
# archives (the NEON asm needs explicit -fPIC to link into libmain.so).
rm -rf "$work" "$outdir/lib"
mkdir -p "$work" "$outdir/lib"

if [ ! -x "$bin/aarch64-linux-android${api}-clang" ]; then
    echo "ERROR: NDK clang not found at $bin/aarch64-linux-android${api}-clang" >&2
    exit 1
fi

echo "::group::Downloading ffmpeg ${FFMPEG_VERSION}"
tar="$work/ffmpeg-n${FFMPEG_VERSION}.tar.gz"
if [ -n "${3:-}" ]; then
    cp -f "$3" "$tar"
else
    curl -fL --retry 3 -o "$tar" \
        "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz"
fi
echo "${FFMPEG_SHA512}  ${tar}" | sha512sum -c - || { echo "ERROR: ffmpeg source checksum mismatch" >&2; exit 1; }
echo "::endgroup::"

echo "::group::Extracting and patching ffmpeg"
rm -rf "$work/src"
mkdir -p "$work/src"
tar xzf "$tar" -C "$work/src" --strip-components=1
src="$work/src"
patch -d "$src" -p1 --forward --silent < "$PATCH" || true
echo "::endgroup::"

echo "::group::Configuring ffmpeg for arm64-android"
# NOTE: NEON asm (tx_float_neon.S) is compiled by a separate assembler that
# does not pick up -fPIC, producing non-PIC relocations that cannot link into
# the shared libmain.so. The xmaframes decoder is pure C, so disable asm.
cd "$src"
./configure \
    --cc="$bin/aarch64-linux-android${api}-clang" \
    --cxx="$bin/aarch64-linux-android${api}-clang++" \
    --ar="$bin/llvm-ar" \
    --ranlib="$bin/llvm-ranlib" \
    --nm="$bin/llvm-nm" \
    --strip="$bin/llvm-strip" \
    --target-os=android \
    --arch=aarch64 \
    --cpu=armv8-a \
    --enable-cross-compile \
    --sysroot="$sysroot" \
    --enable-static --disable-shared \
    --disable-programs --disable-doc --disable-autodetect \
    --enable-pic --extra-cflags="-fPIC" \
    --disable-asm \
    --disable-network --disable-iconv \
    --disable-everything --enable-decoder=xmaframes
echo "::endgroup::"

echo "::group::Building ffmpeg"
make -j"$(nproc)"
echo "::endgroup::"

for lib in libavcodec/libavcodec.a libavformat/libavformat.a libavutil/libavutil.a \
           libswresample/libswresample.a libswscale/libswscale.a libavfilter/libavfilter.a; do
    if [ ! -f "$src/$lib" ]; then
        echo "ERROR: ffmpeg did not produce $lib" >&2
        exit 1
    fi
    cp -f "$src/$lib" "$outdir/lib/$(basename "$lib")"
done

echo "ffmpeg for Android built: $outdir/lib"
ls -la "$outdir/lib"
