pkgs:
pkgs.buildEnv {
  name = "lang-nix";
  paths = [
    # LSP
    pkgs.nil
    pkgs.nixd

    # Linters
    pkgs.statix
    pkgs.deadnix

    # Formatters
    pkgs.nixfmt
    pkgs.nixfmt-tree
    pkgs.alejandra

    # Utilities
    pkgs.nix-tree
    pkgs.nix-diff
  ];
  meta.description = "Nix development environment - LSP, linters, formatters, and utilities";
}
