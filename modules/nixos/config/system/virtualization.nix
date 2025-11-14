{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.psyclyx.system.virtualization;
in
{
  options = {
    psyclyx.system.virtualization = {
      enable = lib.mkEnableOption "Enable virtualization.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
  };
}
