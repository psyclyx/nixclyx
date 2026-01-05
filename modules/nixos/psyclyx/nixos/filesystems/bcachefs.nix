{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.filesystems.bcachefs;
in
{
  options = {
    psyclyx.nixos.filesystems.bcachefs = {
      enable = lib.mkEnableOption "bcachefs";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
