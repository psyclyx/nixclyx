{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.hosts.tleilax;
in {
  imports = [
    ./network.nix
  ];

  options.psyclyx.nixos.config.hosts.tleilax = {
    enable = lib.mkEnableOption "tleilax host";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "tleilax";

    fileSystems = {
      "/" = {
        device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
        fsType = "ext4";
      };
      "/boot" = {
        device = "UUID=C8F3-8E47";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    psyclyx = {
      nixos = {
        hardware.presets.hpe.dl20-gen10.enable = true;

        network.ports.ssh = [17891];

        config = {
          roles.server.enable = true;
        };

        services = {
          tailscale.exitNode = true;
        };
      };
    };
  };
}
