{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe'
    mkDefault
    mkEnableOption
    optionals
    mkForce
    mkIf
    types
    mkOption
    ;

  cfg = config.psyclyx.system.swap;
in
{
  options = {
    psyclyx.system.swap = {
      enable = mkEnableOption "swap config";
      zswap = mkOption {
        type = types.bool;
        default = true;
        description = "zswap (swap to zstd in-memory before disk)";
      };
      swappiness = mkOption {
        type = types.ints.between 0 200;
        default = 60;
        description = "Lower values are suitable for database workloads, desktops, machines with olenty of ram, etc.";
      };
    };
  };

  config = mkIf cfg.enable {
    psyclyx.system.swap.zswap = mkDefault true;
    boot.kernelParams = mkIf cfg.zswap [ "zswap.enabled=1" ];
    boot.kernel.sysctl = {
      "vm.swappiness" = cfg.swappiness;
    };
  };
}
