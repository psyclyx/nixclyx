{
  path = ["psyclyx" "darwin" "config" "roles" "base"];
  description = "base darwin role";
  config = {lib, pkgs, nixclyx, ...}: {
    environment.systemPackages = nixclyx.packageGroups.shell pkgs;

    psyclyx = {
      common.system.nixpkgs.enable = lib.mkDefault true;

      darwin = {
        programs.zsh.enable = lib.mkDefault true;

        system = {
          home-manager.enable = lib.mkDefault true;
          homebrew.enable = lib.mkDefault true;
          nix.enable = lib.mkDefault true;
          nixpkgs.enable = lib.mkDefault true;
          security.enable = lib.mkDefault true;
          settings.enable = lib.mkDefault true;
          stylix.enable = lib.mkDefault true;
        };
      };
    };
  };
}
