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

    psyclyx = {
      filesystems.layouts.bcachefs-pool = {
        enable = true;
        UUID = {
          root = "ccb2b4e2-b5b7-4d85-aca8-039ca1ccc985";
          boot = "71AE-12DD";
        };
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
        enable = true;
      };

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
        home-assistant.enable = true;
        openrgb.enable = true;
        tailscale.exitNode = true;
      };

      system = {
        containers.enable = true;
        emulation.enable = true;
        swap.enable = true;
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
