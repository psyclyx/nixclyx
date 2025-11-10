{
  nixosSystem,
  specialArgs,
  ...
}:
let
  mkSystem = args: nixosSystem ({ inherit specialArgs; } // args);

  hosts = import ./hosts.nix;
in
builtins.mapAttrs (_: mkSystem) hosts
