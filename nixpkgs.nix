{
  nixpkgs ? (import ./npins).nixpkgs,
  overlays ? [(import ./overlays.nix {})],
}:
import nixpkgs {
  inherit overlays;
  config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };
}
