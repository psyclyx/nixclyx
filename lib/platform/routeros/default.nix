# RouterOS platform library.
#
# A NixOS-shaped module system for one MikroTik device: you set
# `routeros.*` options; the platform renders a `.rsc` under
# `system.build`. It knows nothing about egregore or any fleet — a
# fleet's projection is an ordinary module that sets these options.
{ lib, pkgs }:
let
  render = pkgs.callPackage ./render { };
in {
  # The renderer, for direct/edge use.
  inherit render;

  # eval { modules = [...]; specialArgs = {...}; } -> module-system result
  # with `config.routeros` and `config.system.build.*`.
  eval = { modules ? [ ], specialArgs ? { } }:
    lib.evalModules {
      modules = [ ./modules/options.nix ./modules/render.nix ] ++ modules;
      specialArgs = { inherit pkgs; routerosLib = { inherit render; }; } // specialArgs;
    };
}
