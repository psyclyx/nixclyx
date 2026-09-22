{ lib, pkgs }:
let
  render = pkgs.callPackage ./render { };
  cli = pkgs.callPackage ./cli { swos-config = render; };
in {
  inherit render cli;
  eval = { modules ? [ ], specialArgs ? { } }:
    lib.evalModules {
      modules = [ ./modules/options.nix ./modules/render.nix ./modules/actions.nix ] ++ modules;
      specialArgs = { inherit pkgs; swosLib = { inherit render cli; }; platformTool = cli; } // specialArgs;
    };
}
