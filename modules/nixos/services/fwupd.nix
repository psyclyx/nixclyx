{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.services.fwupd;
in
{
  options = {
    psyclyx.services.fwupd.enable = lib.mkEnableOption "fwupd";
  };
  config = lib.mkIf cfg.enable {
    services.fwupd.enable = true;
  };
}
