{...}: {
  psyclyx.nixos.filesystems.layouts.bcachefs-subvols = {
    enable = true;
    rootPartlabel = "sda-root";
    bootPartlabel = "sda-boot";
    subvolumes = {
      "/"          = { subdir = "subvolumes/root"; };
      "/nix"       = { subdir = "subvolumes/nix"; neededForBoot = true; };
      "/var/log"   = { subdir = "subvolumes/log"; neededForBoot = true; };
      "/home/psyc" = { subdir = "subvolumes/home_psyc"; };
      "/root"      = { subdir = "subvolumes/home_root"; };
    };
  };
}
