{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.system.swap;
in
{
  options = {
    psyclyx.nixos.system.swap = {
      enable = lib.mkEnableOption "swap config";
      swappiness = lib.mkOption {
        type = lib.types.ints.between 0 200;
        default = 60;
        description = ''
          RAM/swap bias (0=max ram preference, 200=max swap preference).
          Lower values are suitable for database workloads, desktops, machines with plenty of ram, etc.
        '';
      };

      zswap = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "zswap (swap to zstd in-memory before disk)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      kernel.sysctl."vm.swappiness" = cfg.swappiness;
      kernelParams = lib.mkIf cfg.zswap [ "zswap.enabled=1" ];
    };
  };
}
