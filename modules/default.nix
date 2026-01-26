deps: {
  commonModules = import ./common deps;
  darwinModules.psyclyx = ./darwin deps;
  nixosModules = import ./nixos deps;
  homeManagerModules = import ./home deps;
}
