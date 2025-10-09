{ lib, psyclyxLib, ... }:
let
  mkNixosSystem =
    specialArgs:
    let
      inherit (lib) nixosSystem;
    in
    {
      modules,
      system ? "x86_64-linux",
    }:
    nixosSystem {
      inherit modules specialArgs system;
    };

  mkNixosSystems =
    specialArgs:
    let
      inherit (lib) mapAttrs;
      nixosSystem = mkNixosSystem specialArgs;
    in
    set: mapAttrs (_: nixosSystem) set;
in
{
  inherit mkNixosSystem mkNixosSystems;
}
