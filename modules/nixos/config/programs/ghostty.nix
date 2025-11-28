{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let

  inherit (lib) mkEnableOption mkIf;

  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs.ghostty.packages."${system}") ghostty;

  cfg = config.psyclyx.programs.ghostty;
in
{
  options = {
    psyclyx.programs.ghostty = {
      enable = mkEnableOption "ghostty terminal emulator";
    };
  };

  config = mkIf cfg.enable { environment.systemPackages = [ ghostty ]; };
}
