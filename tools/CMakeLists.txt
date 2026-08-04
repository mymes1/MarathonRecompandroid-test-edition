option(MARATHON_RECOMP_OPTIMIZE_TOOLS "Apply compiler optimizations to build tools." ON)
if (MARATHON_RECOMP_OPTIMIZE_TOOLS)
    if (WIN32)
        add_compile_options(/O2)
    else()
        add_compile_options(-O3)
    endif()
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
endif()

# When cross-compiling for Android the tool executables are never run on the
# target device – they run on the host via MARATHON_RECOMP_HOST_* prebuilts.
# We still need the shared thirdparty libraries (fmt, zstd, xxHash) that the
# game binary links against, so pull those in directly without building the
# recompiler executables themselves.
if (ANDROID)
    set(XENOS_RECOMP_THIRDPARTY_ROOT "${MARATHON_RECOMP_TOOLS_ROOT}/XenosRecomp/thirdparty")
    if (NOT TARGET fmt::fmt)
        add_subdirectory("${XENOS_RECOMP_THIRDPARTY_ROOT}/fmt")
    endif()
    if (NOT TARGET xxHash::xxhash)
        add_subdirectory("${XENOS_RECOMP_THIRDPARTY_ROOT}/xxHash/cmake_unofficial")
    endif()
    if (NOT TARGET libzstd_static AND NOT TARGET libzstd_shared)
        add_subdirectory("${XENOS_RECOMP_THIRDPARTY_ROOT}/zstd/build/cmake")
    endif()
    set(XENON_RECOMP_THIRDPARTY_ROOT "${MARATHON_RECOMP_TOOLS_ROOT}/XenonRecomp/thirdparty")
    if (NOT TARGET tomlplusplus::tomlplusplus)
        add_subdirectory("${XENON_RECOMP_THIRDPARTY_ROOT}/tomlplusplus")
    endif()

    # XenonUtils is needed by the game binary (parses .xex files) even on Android.
    # Because the XenonRecomp executable itself is replaced by prebuilt host tools
    # we skip the full XenonRecomp CMakeLists.txt and add only XenonUtils + its deps.
    # This ensures xbox.h (and related headers) are on the include path for MarathonRecomp.
    set(THIRDPARTY_ROOT "${XENON_RECOMP_THIRDPARTY_ROOT}")
    if (NOT TARGET disasm)
        add_subdirectory("${XENON_RECOMP_THIRDPARTY_ROOT}/disasm"
                         "${CMAKE_BINARY_DIR}/XenonRecomp/thirdparty/disasm")
    endif()
    if (NOT TARGET XenonUtils)
        add_subdirectory("${MARATHON_RECOMP_TOOLS_ROOT}/XenonRecomp/XenonUtils"
                         "${CMAKE_BINARY_DIR}/XenonRecomp/XenonUtils")
    endif()
else()
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/bc_diff)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/file_to_c)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/fshasher)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/u8extract)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/x_decompress)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/XenonRecomp)
    add_subdirectory(${MARATHON_RECOMP_TOOLS_ROOT}/XenosRecomp)
endif()
