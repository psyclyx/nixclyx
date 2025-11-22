{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.system.nixpkgs;
in
{
  options = {
    psyclyx.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (unfree, etc)";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
  };
}
