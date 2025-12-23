{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.hardware.tune.hdd;
in
{
  options = {
    psyclyx.hardware.tune.hdd = {
      enable = mkEnableOption "reasonable, general purpose HDD performance tweaks";
    };
  };

  config = mkIf cfg.enable {
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/nr_requests}="128"
      ACTION=="add|change", KERNEL=="sd*[!0-9]", ATTR{queue/rotational}=="1", ATTR{queue/read_ahead_kb}="1024"
    '';
  };
}
