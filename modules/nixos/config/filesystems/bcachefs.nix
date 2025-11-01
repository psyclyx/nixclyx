{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.psyclyx.filesystems.bcachefs;
in
{
  options = {
    psyclyx.filesystems.bcachefs = {
      enable = mkEnableOption "ZFS";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
