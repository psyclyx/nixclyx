{
  commonModules = import ./common;

  nixosModules.psyclyx = ./nixos/module.nix;

  homeManagerModules.psyclyx = ./home/module.nix;
}
