{
  path = ["psyclyx" "nixos" "hosts" "sigil"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./hardware.nix ./network.nix];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    networking.hostName = "sigil";

    environment.systemPackages = [
      pkgs.audacity
      pkgs.bitwig-studio4
      pkgs.gimp-with-plugins
      pkgs.kicad
      pkgs.orca-slicer
    ];

    psyclyx.nixos = {
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

      programs = {
        glasgow.enable = true;
        steam.enable = true;
      };

      network = {
        dns.client.enable = true;
        firewall = {
          zones.lan.interfaces = ["bond0" "wg0"];
          input.lan.policy = "accept";
        };
      };

      role = "workstation";

      services = {
        openrgb.enable = true;
        tailscale.exitNode = true;
      };

      system = {
        emulation.enable = true;
        swap.swappiness = 5;
      };
    };

    stylix = {
      image = nixclyx.assets.wallpapers."4x-ppmm-mami.jpg";
      base16Scheme = nixclyx.assets.palettes."4x-ppmm-mami.yaml";
      polarity = "dark";
    };
  };
}
