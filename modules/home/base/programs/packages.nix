{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # clojure
    babashka
    clj-kondo
    cljstyle
    clojure
    clojure-lsp
    leiningen
    maven

    # js
    nodejs

    # lua
    lua
    lua-language-server

    # nix
    nixd
    nixfmt-rfc-style

    # python
    python3

    # rust
    cargo
    rustc

    # tools
    fd
    htop
    jet
    jq
    ripgrep

    # zig
    zig
    zls
  ];
}
