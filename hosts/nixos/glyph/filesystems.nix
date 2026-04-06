{...}: {
  psyclyx.nixos.filesystems.layouts.bcachefs-subvols = {
    enable = true;
    rootPartlabel = "nvme0-root";
    bootPartlabel = "nvme0-boot";
    swapPartlabel = "nvme0-swap";
    subvolumes = {
      "/"         = { subdir = "subvolumes/root/@live"; };
      "/nix"      = { subdir = "subvolumes/nix/@live"; neededForBoot = true; };
      "/persist"  = { subdir = "subvolumes/persist/@live"; neededForBoot = true; };
      "/var/log"  = { subdir = "subvolumes/log/@live"; neededForBoot = true; };
      "/home/psyc" = { subdir = "subvolumes/home_psyc/@live"; };
      "/root"     = { subdir = "subvolumes/home_root/@live"; };
    };
  };
}
