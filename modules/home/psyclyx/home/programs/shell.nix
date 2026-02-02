{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.programs.shell;
in {
  options = {
    psyclyx.home.programs.shell = {
      enable = lib.mkEnableOption "generic shell configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    home.shellAliases = {
      "ns" = "nix search nixpkgs";
      "nsp" = "nix-shell --run $SHELL -p";
      "nrs" = "sudo nixos-rebuild switch";

      "ipf" = "ip -4";
      "ips" = "ip -6";
    };

    psyclyx.home.programs = {
      direnv.enable = true;
      zoxide.enable = true;
    };
  };
}
