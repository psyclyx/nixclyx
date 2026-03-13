{
  path = ["psyclyx" "droid" "roles" "base"];
  description = "base nix-on-droid role";
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    environment.packages =
      nixclyx.packageGroups.core pkgs
      ++ [
        pkgs.openssh
        pkgs.man
        pkgs.gnupg
      ];

    android-integration = {
      termux-open.enable = true;
      termux-open-url.enable = true;
      termux-reload-settings.enable = true;
      termux-setup-storage.enable = true;
      termux-wake-lock.enable = true;
      termux-wake-unlock.enable = true;
      xdg-open.enable = true;
    };

    user.shell = "${pkgs.zsh}/bin/zsh";

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [nixclyx.modules.home];
      extraSpecialArgs = {
        osConfig = {};
      };
    };
  };
}
