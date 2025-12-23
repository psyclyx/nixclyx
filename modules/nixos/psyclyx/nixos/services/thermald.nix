{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.thermald;
in
{
  options = {
    psyclyx.nixos.services.thermald = {
      enable = mkEnableOption "thermal throttling daemon for intel cpus";
    };
  };

  config = mkIf cfg.enable {
    services.thermald.enable = true;
  };
}
