{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.system.nix;
in {
  options = {
    psyclyx.nixos.system.nix = {
      enable = lib.mkEnableOption "nix config";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.nix.enable = true;
    nix.settings.trusted-users = ["@wheel"];
  };
}
