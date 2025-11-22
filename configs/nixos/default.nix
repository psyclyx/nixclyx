{ inputs }:
let
  inherit (inputs.nixpkgs.lib) mapAttrs nixosSystem;

  mkSystem = args: nixosSystem ({ specialArgs = { inherit inputs; }; } // args);

  hosts = import ./hosts.nix;
in
mapAttrs (_: mkSystem) hosts
