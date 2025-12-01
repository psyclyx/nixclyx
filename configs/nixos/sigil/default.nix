{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "sigil";

    # Development and specialized environments
    environment.systemPackages = with pkgs.psyclyx.envs; [
      shell
      languages
      "3dprinting"
      forensics
      llm
      media
    ];

    psyclyx = {
      hardware = {
        cpu = {
          amd.enable = true;
          enableMitigations = false;
        };
        gpu.nvidia.enable = true;
      };

      network.enable = true;

      roles = {
        base.enable = true;
        graphical.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      programs = {
        adb.enable = true;
        glasgow.enable = true;
        steam.enable = true;
      };

      services = {
        avahi.enable = true;
        home-assistant.enable = true;
        openrgb.enable = true;
        resolved.enable = true;
        tailscale.exitNode = true;
      };

      system = {
        emulation.enable = true;
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
