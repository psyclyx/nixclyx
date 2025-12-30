{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;

  cfg = config.psyclyx.nixos.system.storage;
in
{
  options = {
    psyclyx.nixos.system.storage = {
      enable = mkEnableOption "storage config";
      tune = {
        hdd = mkOption {
          default = true;
          type = types.bool;
          description = "udev rules for rotational disk perf";
        };

        ssd = mkOption {
          default = true;
          type = types.bool;
          description = "udev rules for ssd perf";
        };

        nvme = mkOption {
          default = true;
          type = types.bool;
          description = "udev rules and kernel params for nvme disk perf";
        };
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.tune.hdd {
      services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/nr_requests}="128"
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="1024"
      '';
    })

    (mkIf cfg.tune.ssd {
      services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="64"
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/nomerges}="1"
        ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/rq_affinity}="2"
      '';
    })

    (mkIf cfg.tune.nvme {
      boot.kernelParams = [
        "nvme.use_threaded_interrupts=1"
        "nvme.use_cmb_sqes=1"
      ];

      services.udev.extraRules = ''
        ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="kyber"
        ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/nr_requests}="64"
        ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/nomerges}="1"
        ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/rq_affinity}="2"
      '';
    })
  ]);
}
