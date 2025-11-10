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
      enable = mkEnableOption "bcachefs";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "bcachefs" ];
  };
}
