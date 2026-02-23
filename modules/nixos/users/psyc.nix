{
  path = ["psyclyx" "nixos" "users" "psyc"];
  description = "psyc user";
  config = {
    pkgs,
    nixclyx,
    ...
  }: {
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

    home-manager.users.psyc.psyclyx.home.profiles.psyc.base.enable = true;
  };
}
