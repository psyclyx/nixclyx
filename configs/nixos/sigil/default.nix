{ config, pkgs, ... }:
{
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
        pkgs.audacity
        pkgs.gimp-with-plugins
        pkgs.kicad
      ];

    psyclyx = {
      nixos = {
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

          monitors = {
            benq = {
              connector = "DP-4";
              identifier = "BNQ BenQ RD280U V5R0042101Q";
              mode = {
                width = 3840;
                height = 2560;
              };
            };

            gawfolk = {
              connector = "DP-2";
              identifier = "QHX GF005 Unknown";
              mode = {
                width = 3840;
                height = 2560;
              };
              position.x = -3840;
            };

            dell = {
              connector = "DP-1";
              identifier = "Dell Inc. DELL S2721QS 9PPZM43";
              mode = {
                width = 3840;
                height = 2160;
              };
              position.x = 3840;
            };
          };
        };

        network = {
          dns.client.enable = true;
        };

        programs = {
          glasgow.enable = true;
          steam.enable = true;
        };

        roles = {
          base.enable = true;
          graphical.enable = true;
          remote.enable = true;
          utility.enable = true;
        };

        services = {
          openrgb.enable = true;
          tailscale.exitNode = true;
        };

        system = {
          emulation.enable = true;
          swap.swappiness = 10;
        };

        users.psyc = {
          enable = true;
        };
      };

    };

    stylix = {
      image = config.psyclyx.nixos.deps.nixclyx.assets.wallpapers."4x-ppmm-mami.jpg";
      polarity = "dark";
    };
  };
}
