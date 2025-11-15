{ inputs, lib, ... }:
{
  imports = [
    ./default.nix
    "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
  ];

  config = {
    psyclyx = {
      boot.systemd-boot.enable = lib.mkForce false;
      host.suffix = "installer";
    };
  };
}
