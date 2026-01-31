{ ... }:
{
  imports = [
    ./network.nix
  ];

  config = {
    networking.hostName = "tleilax";

    fileSystems = {
      "/" = {
        device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
        fsType = "ext4";
      };
      "/boot" = {
        device = "UUID=C8F3-8E47";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };

    psyclyx = {
      nixos = {
        hardware.presets.hpe.dl20-gen10.enable = true;

        network.ports.ssh = [ 17891 ];

        roles = {
          base.enable = true;
          remote.enable = true;
          utility.enable = true;
        };

        services = {
          tailscale.exitNode = true;
        };

        users.psyc = {
          enable = true;
          server = true;
        };
      };
    };
  };
}
