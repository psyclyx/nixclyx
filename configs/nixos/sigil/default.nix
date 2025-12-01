{ inputs, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystems.nix
  ];

  config = {
    networking.hostName = "sigil";

    # Development and specialized environments
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
