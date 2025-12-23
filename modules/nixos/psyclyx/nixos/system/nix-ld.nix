{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.system.nix-ld;
in
{
  options = {
    psyclyx.nixos.system.nix-ld = {
      enable = mkEnableOption "support externally compiled, statically linked binaries via nix-ld";
    };
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
