{
  commonModules = import ./common;

  darwinModules.psyclyx = ./darwin;

  nixosModules = import ./nixos;

  homeManagerModules = import ./home;
}
