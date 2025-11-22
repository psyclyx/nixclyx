{ inputs }:
let
  inherit (inputs.nix-darwin) darwinSystem;

  mkSystem = args: darwinSystem ({ specialArgs = { inherit inputs; }; } // args);

  hosts = import ./halo;
in
builtins.mapAttrs (_: mkSystem) hosts
