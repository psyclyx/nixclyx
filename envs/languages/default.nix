pkgs:
let
  # Import individual language environments
  cEnv = import ./c.nix pkgs;
  rustEnv = import ./rust.nix pkgs;
  zigEnv = import ./zig.nix pkgs;
  nodeEnv = import ./node.nix pkgs;
  clojureEnv = import ./clojure.nix pkgs;
  nixEnv = import ./nix.nix pkgs;
  luaEnv = import ./lua.nix pkgs;
in
{
  # Expose individual languages as attributes
  c = cEnv;
  rust = rustEnv;
  zig = zigEnv;
  node = nodeEnv;
  clojure = clojureEnv;
  nix = nixEnv;
  lua = luaEnv;

  # Combined environment with all languages
  # Usage: languages.full
  # Override: languages.full.override { rust = false; zig = false; }
  full = pkgs.lib.makeOverridable
    (
      {
        c ? false,
        rust ? false,
        zig ? false,
        node ? false,
        clojure ? false,
        nix ? true,
        lua ? false,
      }:
      let
        selected = pkgs.lib.optionals c [ cEnv ]
          ++ pkgs.lib.optionals rust [ rustEnv ]
          ++ pkgs.lib.optionals zig [ zigEnv ]
          ++ pkgs.lib.optionals node [ nodeEnv ]
          ++ pkgs.lib.optionals clojure [ clojureEnv ]
          ++ pkgs.lib.optionals nix [ nixEnv ]
          ++ pkgs.lib.optionals lua [ luaEnv ];
      in
      pkgs.buildEnv {
        name = "languages-full";
        paths = selected;
        meta.description = "Combined language development environment with selected languages";
      }
    )
    { };
}
