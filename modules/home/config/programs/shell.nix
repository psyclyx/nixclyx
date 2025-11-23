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
    home.shell = {
      shellAliases = {
        "ns" = "nix search nixpkgs";
        "nsp" = "nix-shell --run $SHELL -p";
        "nr" = "nixos-rebuild";
        "nrf" = "nixos-rebuild --flake";

        "ipf" = "ip -4";
        "ips" = "ip -6";
        "ifB" = "ip -B";
        "ipL" = "ip -L";
      };
    };

    psyclyx.programs = {
      direnv.enable = true;
      fzf.enable = true;
      zoxide.enable = true;
    };
  };
}
