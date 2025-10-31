{
  commonModules = import ./common;

  darwinModules.psyclyx = ./darwin;

  nixosModules.psyclyx = ./nixos;

  homeManagerModules = import ./home;
}
