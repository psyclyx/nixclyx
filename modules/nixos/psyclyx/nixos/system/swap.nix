{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    types
    mkOption
    ;

  cfg = config.psyclyx.nixos.system.swap;
in
{
  options = {
    psyclyx.nixos.system.swap = {
      enable = mkEnableOption "swap config";
      swappiness = mkOption {
        type = types.ints.between 0 200;
        default = 60;
        description = ''
          RAM/swap bias (0=max ram preference, 200=max swap preference).
          Lower values are suitable for database workloads, desktops, machines with plenty of ram, etc.
        '';
      };

      zswap = mkOption {
        type = types.bool;
        default = true;
        description = "zswap (swap to zstd in-memory before disk)";
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      kernel.sysctl."vm.swappiness" = cfg.swappiness;
      kernelParams = mkIf cfg.zswap [ "zswap.enabled=1" ];
    };
  };
}
