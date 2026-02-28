{
  path = ["psyclyx" "nixos" "hosts" "lab-2"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-2";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "9f6057a5";
        boot.UUID = "F629-CAC1";
        arc.maxBytes = 34359738368; # 32GB
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-id/scsi-35000c50085e8525b-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c50085e87d1b-part2"; }
      { device = "/dev/disk/by-id/scsi-350000394780aef44-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5009792f3b7-part2"; }
    ];
  };
}
