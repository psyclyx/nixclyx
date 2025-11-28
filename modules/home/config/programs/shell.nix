{ config, lib, ... }:
let
  inherit (lib) mkEnableOption;

  cfg = config.psyclyx.programs.shell;
in
{
  options = {
    psyclyx.programs.shell = {
      enable = mkEnableOption "generic shell configuration";
    };
  };

  config = {
    home.shellAliases = {
      "ns" = "nix search nixpkgs";
      "nsp" = "nix-shell --run $SHELL -p";
      "nrs" = "sudo nixos-rebuild switch";

      "ipf" = "ip -4";
      "ips" = "ip -6";
    };

    psyclyx.programs = {
      direnv.enable = true;
      zoxide.enable = true;
    };
  };
}
