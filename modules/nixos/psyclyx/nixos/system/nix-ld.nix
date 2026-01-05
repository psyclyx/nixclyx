{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.system.nix-ld;
in
{
  options = {
    psyclyx.nixos.system.nix-ld = {
      enable = lib.mkEnableOption "support externally compiled, statically linked binaries via nix-ld";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld.enable = true;
  };
}
