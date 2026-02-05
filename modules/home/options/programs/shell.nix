{
  path = ["psyclyx" "home" "programs" "shell"];
  description = "generic shell configuration";
  config = _: {
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
