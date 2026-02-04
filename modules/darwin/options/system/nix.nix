{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.system.nix;
in {
  options.psyclyx.darwin.system.nix = {
    enable = lib.mkEnableOption "nix config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.nix.enable = true;
    nix.settings.trusted-users = ["@admin"];
  };
}
