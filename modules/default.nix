{ lib }:
{
  commonModules = import ./common { inherit lib; };

  darwinModules.psyclyx = ./darwin;

  nixosModules = import ./nixos;

  homeManagerModules = import ./home;
}
