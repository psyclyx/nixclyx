{ inputs, pkgs, ... }:
let
  inherit (inputs) self;
in
{
  networking.hostName = "sigil";

  imports = [
    self.nixosModules.psyclyx
    ./network.nix
    ./filesystems.nix
    ./users.nix
  ];

  psyclyx = {
    roles = {
      base.enable = true;
      forensics.enable = true;
      graphical.enable = true;
      media.enable = true;
      remote.enable = true;
      utility.enable = true;
    };
    hardware = {
      cpu = {
        amd.enable = true;
        enableMitigations = false;
      };
      glasgow.enable = true;
      gpu.nvidia.enable = true;
      rtl8125.disableEEEOn = [ "enp5s0" ];
    };
    programs = {
      adb.enable = true;
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
      virtualization.enable = true;
    };
    stylix = {
      image = self.assets.wallpapers."4x-ppmm-mami.jpg";
      dark = true;
    };
  };
}
