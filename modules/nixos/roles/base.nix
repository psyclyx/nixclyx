{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.roles.base;
in

{
  options = {
    psyclyx.nixos.roles.base = {
      enable = lib.mkEnableOption "role for baseline config, likely applicable to all hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
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

        system = {
          containers.enable = lib.mkDefault true;
          documentation.enable = lib.mkDefault true;
          home-manager.enable = lib.mkDefault true;
          locale.enable = lib.mkDefault true;
          nix.enable = lib.mkDefault true;
          nixpkgs.enable = lib.mkDefault true;
          storage.enable = lib.mkDefault true;
          stylix.enable = lib.mkDefault true;
          swap.enable = lib.mkDefault true;
          timezone.enable = lib.mkDefault true;
        };
      };
    };
  };
}
