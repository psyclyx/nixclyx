{
  config,
  lib,
  pkgs,
  ...
}:
let

  inherit (lib)
    genAttrs
    types
    mkIf
    mkOption
    mkEnableOption
    ;

  cfg = config.psyclyx.hosts.lab.disks;
in
{
  options = {
    psyclyx.hosts.lab.disks = {
      enable = mkEnableOption "disk partitioning/formatting";

      boot = mkOption {
        type = types.nullOr types.str;
        description = "Disk to use for /boot";
      };

      pool = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };
  };

  config = mkIf cfg.enable {
    disko = {
      devices = {
        disks = genAttrs cfg.pool (id: {
          device = "/dev/disk/by-id/${id}";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              bcache = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "bcachefs";
                };
              };
            };
          };
        });
      };
    };
  };
}
