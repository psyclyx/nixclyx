{
  config,
  overlays,
  lib,
  ...
}:
let
  cfg = config.psyclyx.system.nixpkgs;
in
{
  options = {
    psyclyx.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (includes allowUnfree and accepts nvidia license)";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs = {
      inherit overlays;
      config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
    };
  };
}
