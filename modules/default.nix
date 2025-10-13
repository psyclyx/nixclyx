{
  commonModules = import ./common;

  darwinModules.psyclyx = ./darwin;

  nixosModules.psyclyx = ./nixos;

  homeManagerModules.psyclyx = ./home/module.nix;
}
