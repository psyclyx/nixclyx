{
  path = ["psyclyx" "nixos" "config" "users" "psyc"];
  description = "psyc user";
  config = {pkgs, nixclyx, ...}: {
    users.users = {
      psyc = {
        extraGroups = [
          "wheel"
          "video"
        ];

        isNormalUser = true;
        openssh.authorizedKeys.keys = nixclyx.keys.psyc.openssh;
        shell = pkgs.zsh;
      };

      root.openssh.authorizedKeys.keys = nixclyx.keys.psyc.openssh;
    };

    home-manager.users.psyc.psyclyx.home.config.homes.psyc.base.enable = true;
  };
}
