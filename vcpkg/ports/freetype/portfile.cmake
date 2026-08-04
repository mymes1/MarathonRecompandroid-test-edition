if("subpixel-rendering" IN_LIST FEATURES)
    set(SUBPIXEL_RENDERING_PATCH "subpixel-rendering.patch")
endif()

string(REPLACE "." "-" VERSION_HYPHEN "${VERSION}")

vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.freedesktop.org/
    OUT_SOURCE_PATH SOURCE_PATH
    REPO freetype/freetype
    REF "VER-${VERSION_HYPHEN}"
    SHA512 fccfaa15eb79a105981bf634df34ac9ddf1c53550ec0b334903a1b21f9f8bf5eb2b3f9476e554afa112a0fca58ec85ab212d674dfd853670efec876bacbe8a53
    HEAD_REF master
    PATCHES
        0003-Fix-UWP.patch
        brotli-static.patch
        bzip2.patch
        fix-exports.patch
        ${SUBPIXEL_RENDERING_PATCH}
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        zlib          FT_REQUIRE_ZLIB
        bzip2         FT_REQUIRE_BZIP2
        error-strings FT_ENABLE_ERROR_STRINGS
        png           FT_REQUIRE_PNG
        brotli        FT_REQUIRE_BROTLI
    INVERTED_FEATURES
        zlib          FT_DISABLE_ZLIB
        bzip2         FT_DISABLE_BZIP2
        png           FT_DISABLE_PNG
        brotli        FT_DISABLE_BROTLI
)

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    PREFER_NINJA
    OPTIONS
        -DFT_DISABLE_HARFBUZZ=ON
        ${FEATURE_OPTIONS}
)

vcpkg_install_cmake()
vcpkg_copy_pdbs()
vcpkg_fixup_cmake_targets(CONFIG_PATH lib/cmake/freetype)

# Rename for easy usage
file(RENAME "${CURRENT_PACKAGES_DIR}/include/freetype2/freetype" "${CURRENT_PACKAGES_DIR}/include/freetype")
file(RENAME "${CURRENT_PACKAGES_DIR}/include/freetype2/ft2build.h" "${CURRENT_PACKAGES_DIR}/include/ft2build.h")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/freetype2")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

# Fix include dir in targets file
file(READ "${CURRENT_PACKAGES_DIR}/share/freetype/freetype-targets.cmake" CONFIG_MODULE)
string(REPLACE "\${_IMPORT_PREFIX}/include/freetype2" "\${_IMPORT_PREFIX}/include" CONFIG_MODULE "${CONFIG_MODULE}")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/freetype/freetype-targets.cmake" "${CONFIG_MODULE}")

if(NOT VCPKG_BUILD_TYPE)
    file(READ "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/freetype2.pc" _contents)
    string(REPLACE "-I\${includedir}/freetype2" "-I\${includedir}" _contents "${_contents}")
    file(WRITE "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/freetype2.pc" "${_contents}")
endif()

file(READ "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/freetype2.pc" _contents)
string(REPLACE "-I\${includedir}/freetype2" "-I\${includedir}" _contents "${_contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/freetype2.pc" "${_contents}")

vcpkg_fixup_pkgconfig(SKIP_CHECK)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

if(VCPKG_TARGET_IS_WINDOWS)
  set(dll_linkage 1)
  if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(dll_linkage 0)
  endif()
  vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/freetype/config/public-macros.h" "#elif defined( DLL_IMPORT )" "#elif ${dll_linkage}")
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake"
    "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" @ONLY)
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/LICENSE.TXT"
        "${SOURCE_PATH}/docs/FTL.TXT"
        "${SOURCE_PATH}/docs/GPLv2.TXT"
)
