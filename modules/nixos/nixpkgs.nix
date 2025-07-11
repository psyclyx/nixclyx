{ overlays, ... }:
{
  nixpkgs = {
    inherit overlays;
    config = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
  };
}
