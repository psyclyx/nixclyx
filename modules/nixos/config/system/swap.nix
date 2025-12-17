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
    mkForce
    mkIf
    mkMerge
    optionalAttrs
    ;

  cfg = config.psyclyx.system.swap;
in
{
  options = {
    psyclyx.system.swap = {
      enable = mkEnableOption "swap configuration";

      auto = mkEnableOption "swapon all partitions with label swap-ssd (with discard) and swap-hdd (no discard)";

      zswap = mkEnableOption "zswap";
    };
  };

  config = mkIf cfg.enable {
    boot.kernelParams = mkIf cfg.zswap [ "zswap.enabled=1" ];

    psyclyx.system.swap = {
      auto = mkDefault true;
      zswap = mkDefault true;
    };

    systemd.services = mkIf cfg.auto (
      let
        blkid = getExe' pkgs.util-linux "blkid";
        swapon = getExe' pkgs.util-linux "swapon";
      in
      {
        swap-hdd = {
          description = "Activate labeled HDD swap";
          before = [ "swap.target" ];
          wantedBy = [ "swap.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            for device in $(${blkid} -t LABEL=swap-hdd -o device); do
              if ! ${swapon} --show=NAME --noheadings | grep -q "^$device$"; then
                echo "Enabling HDD swap on $device (priority 10)"
                ${swapon} -p 10 "$device"
              fi
            done
          '';
        };

        swap-ssd = {
          description = "Activate labeled SSD swap";
          before = [ "swap.target" ];
          wantedBy = [ "swap.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            for device in $(${blkid} -t LABEL=swap-ssd -o device); do
              if ! ${swapon} --show=NAME --noheadings | grep -q "^$device$"; then
                echo "Enabling SSD swap on $device (priority 100, discard)"
                ${swapon} -d -p 100 "$device"
              fi
            done
          '';
        };
      }
    );

    swapDevices = mkIf cfg.auto (mkForce [ ]);
  };
}
