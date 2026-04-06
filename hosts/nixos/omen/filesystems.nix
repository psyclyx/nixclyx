{...}: {
  psyclyx.nixos.filesystems.layouts.btrfs-luks = {
    enable = true;
    luksUUID = "ad19e9a8-82ee-4d6f-a099-288b15bbfce6";
    fsUUID = "2f7b6389-e485-4052-9099-4051ec7e8937";
    bootUUID = "0B7A-BCCA";
    swapUUID = "5613edab-b7a6-40a1-ba7e-777aad805837";
    subvolumes = {
      "/"       = "@";
      "/home"   = "@home";
      "/nix"    = "@nix";
      "/persist" = "@persist";
      "/var"    = "@var";
    };
  };
}
