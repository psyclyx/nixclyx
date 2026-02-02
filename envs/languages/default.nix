pkgs: let
  # Import individual language environments
  cEnv = import ./c.nix pkgs;
  rustEnv = import ./rust.nix pkgs;
  zigEnv = import ./zig.nix pkgs;
  nodeEnv = import ./node.nix pkgs;
  clojureEnv = import ./clojure.nix pkgs;
  nixEnv = import ./nix.nix pkgs;
  luaEnv = import ./lua.nix pkgs;

  # Combined environment with all languages
  fullLanguages = pkgs.buildEnv {
    name = "languages-full";
    paths = [
      cEnv
      rustEnv
      zigEnv
      nodeEnv
      clojureEnv
      nixEnv
      luaEnv
    ];
    meta.description = "Complete language development environment with all languages";
  };
in
  # Return the full languages derivation with individual languages as attributes
  fullLanguages
  // {
    c = cEnv;
    rust = rustEnv;
    zig = zigEnv;
    node = nodeEnv;
    clojure = clojureEnv;
    nix = nixEnv;
    lua = luaEnv;
  }
