{
  path = ["psyclyx" "nixos" "config" "hosts" "omen"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./filesystems.nix];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
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

      network.wireless.enable = true;

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
      image = nixclyx.assets.wallpapers."2x-ppmm-madoka-homura.png";
      polarity = "dark";
    };
  };
}
