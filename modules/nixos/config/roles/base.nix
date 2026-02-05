{
  path = ["psyclyx" "nixos" "config" "roles" "base"];
  description = "base NixOS role";
  config = {lib, pkgs, nixclyx, ...}: {
    environment.systemPackages = nixclyx.packageGroups.shell pkgs;

    psyclyx = {
      common = {
        system = {
          nixpkgs.enable = lib.mkDefault true;
        };
      };

      nixos = {
        boot = {
          systemd = {
            initrd.enable = lib.mkDefault true;
            loader.enable = lib.mkDefault true;
          };
        };

        filesystems = {
          bcachefs.enable = lib.mkDefault true;
        };

        network.networkd.enable = true;

        programs = {
          zsh.enable = lib.mkDefault true;
        };

        services = {
          fwupd.enable = lib.mkDefault true;
          locate.enable = lib.mkDefault true;
          openssh.enable = lib.mkDefault true;
          tailscale.enable = lib.mkDefault true;
        };

        system = {
          containers.enable = lib.mkDefault true;
          documentation.enable = lib.mkDefault true;
          home-manager.enable = lib.mkDefault true;
          locale.enable = lib.mkDefault true;
          nix.enable = lib.mkDefault true;
          nixpkgs.enable = lib.mkDefault true;
          storage.enable = lib.mkDefault true;
          stylix.enable = lib.mkDefault true;
          sudo.enable = lib.mkDefault true;
          swap.enable = lib.mkDefault true;
          timezone.enable = lib.mkDefault true;
          yubikey.enable = lib.mkDefault true;
        };
      };
    };
  };
}
