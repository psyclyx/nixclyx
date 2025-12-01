pkgs:
let
  # Clojure needs node for ClojureScript support
  nodeEnv = import ./node.nix pkgs;
in
pkgs.buildEnv {
  name = "lang-clojure";
  paths = [
    # JDK
    pkgs.temurin-bin

    # Runtime and build tools
    pkgs.clojure
    pkgs.leiningen
    pkgs.babashka

    # CLI tools
    pkgs.neil
    pkgs.jet

    # Native compilation
    pkgs.graalvmPackages.graalvm-ce

    # LSP
    pkgs.clojure-lsp

    # Linters
    pkgs.clj-kondo

    # ClojureScript support via node
    nodeEnv
  ];
  meta.description = "Clojure development environment - JDK, clojure, lein, babashka, graalvm, tooling, and node for ClojureScript";
}
