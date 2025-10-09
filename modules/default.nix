{
  commonModules = import ./common;

  nixosModules.psyclyx = ./nixos;

  homeManagerModules.psyclyx = ./home/module.nix;
}
