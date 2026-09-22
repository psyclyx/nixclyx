# iLO platform library — `eval { modules; specialArgs }`.
{ lib, pkgs }:
let
  render = pkgs.callPackage ./render { };
in {
  inherit render;
  eval = { modules ? [ ], specialArgs ? { } }:
    lib.evalModules {
      modules = [ ./modules/options.nix ./modules/render.nix ] ++ modules;
      specialArgs = { inherit pkgs; iloLib = { inherit render; }; } // specialArgs;
    };
}
