{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.nixos.filesystems.bcachefs;
in
{
  options = {
    psyclyx.nixos.filesystems.bcachefs = {
      enable = mkEnableOption "bcachefs";
    };
  };

  config = mkIf cfg.enable {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
