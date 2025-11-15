{ inputs, lib, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
  ];

  config = {
    networking.hostName = "lab-installer";

    psyclyx = {
      boot.systemd-boot.enable = false;

      hardware.presets.hpe.dl360-gen9.enable = true;

      filesystems.bcachefs.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
        server = true;
      };
    };
  };
}
