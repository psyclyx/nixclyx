{ inputs }:
{
  common = import ./common;
  nixosConfigurations = import ./nixos { inherit inputs; };
  darwinConfigurations = import ./darwin { inherit inputs; };
}
