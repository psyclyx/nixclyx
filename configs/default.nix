deps: {
  common = import ./common;
  nixosConfigurations = import ./nixos deps;
  darwinConfigurations = import ./darwin deps;
}
