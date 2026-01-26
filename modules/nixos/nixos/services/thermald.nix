{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.thermald;
in
{
  options = {
    psyclyx.nixos.services.thermald = {
      enable = lib.mkEnableOption "thermal throttling daemon for intel cpus";
    };
  };

  config = lib.mkIf cfg.enable {
    services.thermald.enable = true;
  };
}
