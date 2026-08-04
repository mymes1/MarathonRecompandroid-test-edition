{pkgs}: {
  deps = [
    pkgs.pkg-config
    pkgs.unzip
    pkgs.curl
    pkgs.llvm
    pkgs.clang
    pkgs.ninja
    pkgs.cmake
  ];
}
