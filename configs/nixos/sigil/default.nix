{ inputs, pkgs, ... }:
{
  imports = [ inputs.self.nixosModules.config ];

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
      ];

    fileSystems = {
      "/" = {
        device = "LABEL=bcachefs";
        fsType = "bcachefs";
      };
      "/boot" = {
        device = "PARTLABEL=boot";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
    };

    psyclyx = {
      filesystems.bcachefs.enable = true;

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
        containers.enable = true;
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
