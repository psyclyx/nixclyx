{ inputs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/platform/nixos/tailscale.nix
    ../../modules/platform/nixos/base
    ../../modules/platform/nixos/physical
    ../../modules/platform/nixos/graphical
    ../../modules/platform/nixos/services/printing.nix
    ../../modules/platform/nixos/programs/adb.nix
    ../../modules/platform/nixos/programs/steam.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
    ./secrets.nix
  ];

  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  virtualisation.docker.enable = true;

  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
      "zha"
      "ios"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };
    };
  };
}
