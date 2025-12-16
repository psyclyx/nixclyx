{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
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
