{ lib, pkgs, nixclyx, ... }: {
  imports = [./filesystems.nix];

  networking.hostName = "omen";

  boot.kernelParams = ["snd-intel-dspcfg.dsp_driver=1"];

  psyclyx.nixos = {
    hardware = {
      cpu = {
        enableMitigations = false;
        intel.enable = true;
      };

      gpu.intel.enable = true;
    };

    network = {
      wireless.enable = true;
      firewall = {
        zones.local.interfaces = ["wl*" "wg0"];
        input.local.policy = "accept";
      };
    };

    services = {
      fstrim.enable = true;
      kanata.enable = true;
      resolved.enable = true;
      thermald.enable = true;
    };

    system = {
      emulation.enable = true;
    };

    role = "workstation";
  };

  stylix = {
    image = "${nixclyx.assets}/wallpapers/2x-ppmm-madoka-homura.png";
    base16Scheme = "${nixclyx.assets}/palettes/2x-ppmm-madoka-homura.yaml";
    polarity = "dark";
  };
}
