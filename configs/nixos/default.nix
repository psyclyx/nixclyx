{ psyclyxLib, specialArgs, ... }:
let
  inherit (psyclyxLib.nixos) mkNixosSystems;

  hosts = import ./hosts;

  nixosSystems = mkNixosSystems specialArgs;
in
nixosSystems hosts
