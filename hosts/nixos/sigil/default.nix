{ lib, pkgs, nixclyx, ... }: {
  imports = [./hardware.nix ./network.nix ./filesystems.nix];

  networking.hostName = "sigil";

  environment.systemPackages = [
    pkgs.audacity
    pkgs.bitwig-studio4
    pkgs.gimp-with-plugins
    pkgs.kicad
    pkgs.orca-slicer
  ];

  psyclyx.nixos = {
    # TODO: enable after migration is verified and /persist is populated
    # filesystems.impermanence = {
    #   enable = true;
    #   device = "UUID=055d9737-c13b-4262-abe6-2ebcb8681307";
    # };

    programs = {
      glasgow.enable = true;
      steam.enable = true;
    };

    network = {
      dns.client.enable = true;
      firewall = {
        zones.lan.interfaces = ["br0" "wg0"];
        input.lan.policy = "accept";
      };
    };

    role = "workstation";

    services = {
      openrgb.enable = true;
      tailscale.exitNode = true;
      icecream = {
        enable = true;
        schedulerHost = "10.0.25.11"; # lab-1 via WireGuard
        noRemote = true;
      };
    };

    system = {
      emulation.enable = true;
      swap.swappiness = 5;
    };
  };

  stylix = {
    image = "${nixclyx.assets}/wallpapers/4x-ppmm-mami.jpg";
    base16Scheme = "${nixclyx.assets}/palettes/4x-ppmm-mami.yaml";
    polarity = "dark";
  };
}
