if (NOT DEFINED FFMPEG_CORE_NAME)
	set(FFMPEG_CORE_NAME ffmpeg)
endif()

add_library(${FFMPEG_CORE_NAME} INTERFACE)

target_include_directories(${FFMPEG_CORE_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Detect OS
if (WIN32 AND NOT MINGW)
	set(FFMPEG_PREBUILTS_NAME "ffmpeg-windows")
elseif (APPLE)
	set(FFMPEG_PREBUILTS_NAME "ffmpeg-macos")
elseif (ANDROID)
	set(FFMPEG_PREBUILTS_NAME "ffmpeg-android")
elseif (UNIX)
	set(FFMPEG_PREBUILTS_NAME "ffmpeg-linux")
elseif (MINGW)
	set(FFMPEG_PREBUILTS_NAME "ffmpeg-mingw")
else ()
	message(FATAL_ERROR "Unsupported OS.")
endif ()

# Detect Architecture
if(NOT DEFINED ARCHITECTURE)
	message(FATAL_ERROR "ARCHITECTURE variable is not set up")
elseif (ARCHITECTURE STREQUAL "x86_64")
	set(FFMPEG_PREBUILTS_NAME "${FFMPEG_PREBUILTS_NAME}-x64.zip")
elseif(ARCHITECTURE STREQUAL "arm64")
	set(FFMPEG_PREBUILTS_NAME "${FFMPEG_PREBUILTS_NAME}-arm64.zip")
elseif(APPLE AND "x86_64" IN_LIST ARCHITECTURE AND "arm64" IN_LIST ARCHITECTURE) # macOS universal
	set(FFMPEG_PREBUILTS_NAME "${FFMPEG_PREBUILTS_NAME}-universal.zip")
else ()
	message(FATAL_ERROR "Unsupported architecture.")
endif()

# Compute current short git commit SHA. When this directory is vendored into another
# repository (e.g. the MarathonRecomp Android port) it is no longer its own git
# repository, so fall back to the FFMPEG_CORE_SHA cache variable (defaults to the
# commit whose headers are vendored in include/).
set(FFMPEG_CORE_SHA "5089f00" CACHE STRING "ffmpeg-core revision whose prebuilt binaries and headers are used")
execute_process(
	COMMAND git rev-parse --short HEAD
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	OUTPUT_VARIABLE FFMPEG_GIT_SHA
	OUTPUT_STRIP_TRAILING_WHITESPACE
	ERROR_QUIET)
if (FFMPEG_GIT_SHA STREQUAL "")
	set(FFMPEG_GIT_SHA "${FFMPEG_CORE_SHA}")
endif()

# A directory with prebuilt static ffmpeg libs (lib/*.a) - e.g. produced by
# tools/ci/build_ffmpeg_android.sh. Skips the download/extract step entirely.
set(FFMPEG_CORE_LOCAL_LIB_DIR "" CACHE PATH "Directory containing prebuilt static ffmpeg libraries (lib/*.a)")

if (FFMPEG_CORE_LOCAL_LIB_DIR)
	set(FFMPEG_LIB_PATH "${FFMPEG_CORE_LOCAL_LIB_DIR}")
else ()
	# Download prebuilt ffmpeg
	set(FFMPEG_CORE_LOCAL_ZIP "" CACHE FILEPATH "Path to a local ffmpeg-<arch>.zip to use instead of downloading")
	set(FFMPEG_ZIP_PATH "${CMAKE_BINARY_DIR}/external/ffmpeg-${FFMPEG_GIT_SHA}.zip")
	if (FFMPEG_CORE_LOCAL_ZIP)
		set(FFMPEG_ZIP_PATH "${FFMPEG_CORE_LOCAL_ZIP}")
		message(STATUS "Using local FFMPEG prebuilts at ${FFMPEG_ZIP_PATH}")
	elseif (NOT EXISTS "${FFMPEG_ZIP_PATH}")
		message(STATUS "Downloading FFMPEG prebuilts...")
		file(DOWNLOAD https://github.com/sonicnext-dev/ffmpeg-core/releases/download/${FFMPEG_GIT_SHA}/${FFMPEG_PREBUILTS_NAME}
				"${FFMPEG_ZIP_PATH}" SHOW_PROGRESS
				STATUS FILE_STATUS)
		list(GET FILE_STATUS 0 STATUS_CODE)
		if (NOT STATUS_CODE EQUAL 0)
			file(REMOVE "${FFMPEG_ZIP_PATH}") # CMake create 0 byte file even if URL is invalid. So need to delete it.
			if (ANDROID)
				message(FATAL_ERROR "No FFMPEG prebuilt found with corresponding commit SHA (${FFMPEG_GIT_SHA}). "
					"The Android build needs ffmpeg-android-arm64.zip from the sonicnext-dev/ffmpeg-core releases "
					"(the upstream project does not publish one yet - build ffmpeg for arm64-android and publish "
					"it, or place the zip at ${FFMPEG_ZIP_PATH} so the download step is skipped).")
			else()
				message(FATAL_ERROR "No FFMPEG prebuilt found with corresponding commit SHA (${FFMPEG_GIT_SHA})")
			endif()
		endif ()
	endif ()

	set(FFMPEG_LIB_PATH "${CMAKE_BINARY_DIR}/external/ffmpeg-${FFMPEG_GIT_SHA}/lib")
	if (NOT EXISTS "${FFMPEG_LIB_PATH}")
		file(MAKE_DIRECTORY "${FFMPEG_LIB_PATH}")
		execute_process(COMMAND ${CMAKE_COMMAND} -E tar xzf "${FFMPEG_ZIP_PATH}"
			WORKING_DIRECTORY "${FFMPEG_LIB_PATH}")
	endif ()
endif ()

set(LIB_PREFIX "lib")
set(LIB_EXT "a")
if (WIN32 AND NOT MINGW)
	set(LIB_PREFIX "")
	set(LIB_EXT "lib")
	target_link_libraries(${FFMPEG_CORE_NAME} INTERFACE
		"psapi;strmiids;uuid;oleaut32;shlwapi;ws2_32;ole32;user32;bcrypt")
elseif (APPLE)
	target_link_libraries(${FFMPEG_CORE_NAME} INTERFACE
		"-framework CoreServices" "-framework CoreFoundation" "-framework AudioUnit"
		"-framework AudioToolbox" "-framework CoreAudio" "-framework CoreMedia"
		"-framework VideoToolbox" "-framework CoreVideo" "-framework Security")
elseif (ANDROID)
	target_link_libraries(${FFMPEG_CORE_NAME} INTERFACE "log" "z" "m")
endif ()

target_link_libraries(${FFMPEG_CORE_NAME} INTERFACE
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}avformat.${LIB_EXT}"
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}avcodec.${LIB_EXT}"
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}swscale.${LIB_EXT}"
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}avutil.${LIB_EXT}"
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}avfilter.${LIB_EXT}"
	"${FFMPEG_LIB_PATH}/${LIB_PREFIX}swresample.${LIB_EXT}")
