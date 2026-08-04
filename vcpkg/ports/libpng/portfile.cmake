vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO glennrp/libpng
    REF v${VERSION}
    SHA512 c023bc7dcf3d0ea045a63204f2266b2c53b601b99d7c5f5a7b547bc9a48b205a277f699eefa47f136483f495175b226527097cd447d6b0fbceb029eb43638f63
    HEAD_REF master
    PATCHES
        cmake.patch
        libm.patch
        pkgconfig.patch
        fix-msa-support-for-mips.patch
        fix-tools-static.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" PNG_SHARED)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" PNG_STATIC)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools PNG_TOOLS
    INVERTED_FEATURES
        tools SKIP_INSTALL_PROGRAMS
)

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    PREFER_NINJA
    OPTIONS
        -DPNG_STATIC=${PNG_STATIC}
        -DPNG_SHARED=${PNG_SHARED}
        -DPNG_FRAMEWORK=OFF
        -DPNG_TESTS=OFF
        -DSKIP_INSTALL_EXECUTABLES=ON
        -DSKIP_INSTALL_FILES=OFF
        ${FEATURE_OPTIONS}
    OPTIONS_DEBUG
        -DSKIP_INSTALL_HEADERS=ON
)

vcpkg_install_cmake()
vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/PNG TARGET_PATH share/png)
vcpkg_fixup_cmake_targets(CONFIG_PATH lib/libpng)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/png")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/libpng-config.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_fixup_pkgconfig(SKIP_CHECK)

if(NOT VCPKG_BUILD_TYPE)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc" "-lpng16" "-lpng16d")
    file(INSTALL "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libpng16.pc"
         DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig"
         RENAME "libpng.pc")
endif()
file(INSTALL "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/libpng16.pc"
     DESTINATION "${CURRENT_PACKAGES_DIR}/lib/pkgconfig"
     RENAME "libpng.pc")

vcpkg_copy_pdbs()

if(PNG_TOOLS)
    vcpkg_copy_tools(TOOL_NAMES "pngfix" "png-fix-itxt" AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
