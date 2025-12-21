{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.tune.ssd;
in
{
  options = {
    psyclyx.hardware.tune.ssd = {
      enable = mkEnableOption "reasonable, general purpose SSD performance tweaks";
    };
  };

  config = mkIf cfg.enable {
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="64"
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/nomerges}="1"
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="0", ATTR{queue/rq_affinity}="2"
    '';
  };
}
