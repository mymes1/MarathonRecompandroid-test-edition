vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/brotli
    REF v${VERSION}
    SHA512 6eb280d10d8e1b43d22d00fa535435923c22ce8448709419d676ff47d4a644102ea04f488fc65a179c6c09fee12380992e9335bad8dfebd5d1f20908d10849d9
    HEAD_REF master
    PATCHES
        install.patch
        fix-arm-uwp.patch
        pkgconfig.patch
        emscripten.patch
)

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    PREFER_NINJA
    OPTIONS
        -DBROTLI_DISABLE_TESTS=ON
)
vcpkg_install_cmake()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig(SKIP_CHECK)
vcpkg_fixup_cmake_targets(CONFIG_PATH share/unofficial-brotli)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/tools")

vcpkg_copy_tools(TOOL_NAMES "brotli" SEARCH_DIR "${CURRENT_PACKAGES_DIR}/tools/brotli")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
