{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-4";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "2045d648-6619-4f7a-bb05-bde2024fa1a4";
        boot = "9222-2E54";
      };
    };
  };
}
