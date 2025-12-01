pkgs:
pkgs.buildEnv {
  name = "lang-rust";
  paths = [
    # Compiler and toolchain
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.clippy

    # LSP
    pkgs.rust-analyzer

    # Additional cargo utilities
    pkgs.cargo-watch
    pkgs.cargo-edit
    pkgs.cargo-outdated
    pkgs.cargo-audit
  ];
  meta.description = "Rust development environment - rustc, cargo, rust-analyzer, and essential cargo tools";
}
