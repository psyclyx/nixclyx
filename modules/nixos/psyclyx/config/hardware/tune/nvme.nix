{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.tune.nvme;
in
{
  options = {
    psyclyx.hardware.tune.nvme = {
      enable = mkEnableOption "reasonable, general purpose NVME performance tweaks";
    };
  };

  config = mkIf cfg.enable {
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
  };
}
