{ lib, pkgs }:
let
  render = pkgs.callPackage ./render { };
  cli = pkgs.callPackage ./cli {
    ilo-config = render;
    ilo4-console = pkgs.callPackage ../../../packages/ilo4-console.nix { };
  };
in {
  inherit render cli;
  eval = { modules ? [ ], specialArgs ? { } }:
    lib.evalModules {
      modules = [ ./modules/options.nix ./modules/render.nix ] ++ modules;
      specialArgs = { inherit pkgs; iloLib = { inherit render cli; }; platformTool = cli; } // specialArgs;
    };
}
