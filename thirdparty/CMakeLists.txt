cmake_policy(SET CMP0077 NEW)

set(MSDF_ATLAS_BUILD_STANDALONE OFF)
set(MSDF_ATLAS_USE_SKIA OFF)
set(MSDF_ATLAS_NO_ARTERY_FONT ON)
set(MSDFGEN_DISABLE_PNG ON)

set(SDL2MIXER_DEPS_SHARED OFF)
set(SDL2MIXER_VENDORED ON)
set(SDL2MIXER_FLAC OFF)
set(SDL2MIXER_MOD OFF)
set(SDL2MIXER_MP3 OFF)
set(SDL2MIXER_MIDI OFF)
set(SDL2MIXER_OPUS OFF)
set(SDL2MIXER_VORBIS "VORBISFILE")
set(SDL2MIXER_WAVPACK OFF)

if (CMAKE_SYSTEM_NAME MATCHES "Linux" OR ANDROID)
    set(PLUME_SDL_VULKAN_ENABLED ON CACHE BOOL "")
endif()

if (WIN32)
    set(PLUME_D3D12_AGILITY_SDK_ENABLED ON CACHE BOOL "")
endif()

if (APPLE AND CMAKE_OSX_ARCHITECTURES)
    set(BASE_ARCHITECTURE "${CMAKE_OSX_ARCHITECTURES}")
elseif (CMAKE_SYSTEM_PROCESSOR)
    set(BASE_ARCHITECTURE "${CMAKE_SYSTEM_PROCESSOR}")
else()
    set(BASE_ARCHITECTURE "${CMAKE_HOST_SYSTEM_PROCESSOR}")
endif()

# Next, match common architecture strings down to a known common value.
if (BASE_ARCHITECTURE MATCHES "(x86)|(X86)|(amd64)|(AMD64)")
    set(ARCHITECTURE "x86_64")
elseif (BASE_ARCHITECTURE MATCHES "(aarch64)|(AARCH64)|(arm64)|(ARM64)")
    set(ARCHITECTURE "arm64")
else()
    message(FATAL_ERROR "Unsupported CPU architecture: ${BASE_ARCHITECTURE}")
endif()

# For Android cross-compiles vcpkg is not used, so build freetype from the
# bundled source tree and expose the Freetype::Freetype target before
# msdf-atlas-gen (which requires it via msdfgen-ext).
if (ANDROID)
    set(FT_DISABLE_ZLIB      ON  CACHE BOOL "" FORCE)
    set(FT_DISABLE_BZIP2     ON  CACHE BOOL "" FORCE)
    set(FT_DISABLE_PNG       ON  CACHE BOOL "" FORCE)
    set(FT_DISABLE_HARFBUZZ  ON  CACHE BOOL "" FORCE)
    set(FT_DISABLE_BROTLI    ON  CACHE BOOL "" FORCE)
    set(FT_ENABLE_ERROR_STRINGS OFF CACHE BOOL "" FORCE)
    add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/freetype" freetype_build)
    # msdfgen calls find_package(Freetype) – satisfy it with the in-tree target.
    if (NOT TARGET Freetype::Freetype)
        add_library(Freetype::Freetype ALIAS freetype)
    endif()
    set(FREETYPE_FOUND TRUE CACHE BOOL "" FORCE)
    set(FREETYPE_INCLUDE_DIRS "${MARATHON_RECOMP_THIRDPARTY_ROOT}/freetype/include" CACHE PATH "" FORCE)
    set(FREETYPE_LIBRARIES freetype CACHE STRING "" FORCE)
endif()

add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/msdf-atlas-gen")

# The GUI installer wizard (and its native file picker dependency) is not built for
# Android; game files are pushed manually instead. See main.cpp __ANDROID__ guards.
if (NOT ANDROID)
    add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/nativefiledialog-extended")
endif()

add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/o1heap")
add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/SDL")
add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/SDL_mixer")
add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/plume")
add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/ffmpeg-core")

# Allows loading a custom Vulkan driver (Mesa Turnip) instead of the vendor
# proprietary blob, to work around driver-side issues seen with this engine's
# buffer_device_address-based bindless resource access. See vulkan_driver_android.cpp.
if (ANDROID)
    add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/libadrenotools")
endif()

if (APPLE)
    add_subdirectory("${MARATHON_RECOMP_THIRDPARTY_ROOT}/MoltenVK")
endif()
