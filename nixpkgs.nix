{
  nixpkgs ? (import ./npins).nixpkgs,
  overlays ? [(import ./overlay.nix)],
}:
import nixpkgs {
  inherit overlays;
  config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };
}
