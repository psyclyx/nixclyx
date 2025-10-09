{ psyclyxLib, specialArgs, ... }:
let
  inherit (psyclyxLib.nixos) mkNixosSystems;

  hosts = import ./hosts.nix;

  nixosSystems = mkNixosSystems specialArgs;
in
nixosSystems hosts
