{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.system.nixpkgs;
in {
  options = {
    psyclyx.nixos.system.nixpkgs = {
      enable = lib.mkEnableOption "nixpkgs config";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.nixpkgs.enable = true;
  };
}
