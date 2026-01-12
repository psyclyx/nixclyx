{ inputs, pkgs, ... }:
{
  imports = [ inputs.self.nixosModules.psyclyx ];

  config = {
    networking.hostName = "sigil";

    environment.systemPackages =
      let
        inherit (pkgs.psyclyx) envs;
      in
      [
        envs._3DPrinting
        envs.forensics
        envs.languages
        envs.llm
        envs.media
        envs.shell

        pkgs.android-tools
      ];

    psyclyx = {
      nixos = {
        programs = {
          glasgow.enable = true;
          steam.enable = true;
        };

        services = {
          openrgb.enable = true;
          tailscale.exitNode = true;
        };

        system = {
          emulation.enable = true;
          swap.swappiness = 10;
        };
      };

      filesystems.layouts.bcachefs-pool = {
        enable = true;
        UUID = {
          root = "ccb2b4e2-b5b7-4d85-aca8-039ca1ccc985";
          boot = "71AE-12DD";
        };
        wants = [
          "/dev/disk/by-id/nvme-eui.0025384c41416f3c"
          "/dev/disk/by-id/nvme-eui.ace42e00457c0fbf2ee4ac0000000001"
        ];
      };

      hardware = {
        cpu = {
          amd.enable = true;
          enableMitigations = false;
        };
        gpu.nvidia.enable = true;
      };

      network = {
        dns.client.enable = true;
      };

      roles = {
        base.enable = true;
        graphical.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
      };
    };

    stylix = {
      image = inputs.self.assets.wallpapers."4x-ppmm-mami.jpg";
      polarity = "dark";
    };
  };
}
