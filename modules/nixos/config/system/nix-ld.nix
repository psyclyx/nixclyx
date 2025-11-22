{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.psyclyx.system.nix-ld;
in
{
  options = {
    psyclyx.system.nix-ld = {
      enable = mkEnableOption "nix-ld so dynamically linked non-nixos binaries find their libraries";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
