{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.psyclyx
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
  ];

  config = {
    networking.hostName = "lab-installer";

    psyclyx = {
      nixos = {
        boot.systemd.loader.enable = false;
      };

      hardware.presets.hpe.dl360-gen9.enable = true;

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
