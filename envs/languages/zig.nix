pkgs:
pkgs.buildEnv {
  name = "lang-zig";
  paths = [
    # Compiler (includes formatter and build system)
    pkgs.zig

    # LSP
    pkgs.zls
  ];
  meta.description = "Zig development environment - zig compiler and zls language server";
}
