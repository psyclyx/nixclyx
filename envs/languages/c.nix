pkgs:
pkgs.buildEnv {
  name = "lang-c";
  paths = [
    # Compilers
    pkgs.gcc
    pkgs.clang

    # Build tools
    pkgs.gnumake
    pkgs.cmake
    pkgs.meson
    pkgs.ninja

    # Debuggers
    pkgs.gdb
    pkgs.lldb

    # LSP
    pkgs.clang-tools # provides clangd

    # Linters
    # clang-tools also provides clang-tidy

    # Formatters
    # clang-tools also provides clang-format

    # Other utilities
    pkgs.valgrind
    pkgs.ccache
  ];
  meta.description = "C/C++ development environment - compilers, debuggers, LSP, build tools";
}
