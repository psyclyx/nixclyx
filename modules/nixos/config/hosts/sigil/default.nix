{
  path = ["psyclyx" "nixos" "config" "hosts" "sigil"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./hardware.nix ./network.nix ./wireguard.nix];
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
          "/dev/disk/by-id/ata-ST4000NM0035-1V4107_ZC12M6AQ" # hdd
          "/dev/disk/by-id/ata-WDC_WDS500G2B0A-00SM50_194894802985" # ssd
        ];
      };

      programs = {
        glasgow.enable = true;
        steam.enable = true;
      };

      network.dns.client.enable = true;

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
      polarity = "dark";
    };
  };
}
