{
  path = ["psyclyx" "nixos" "hosts" "lab-3"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-3";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "e5955fc5";
        boot.UUID = "6CBD-53CD";
        arc.maxBytes = 42949672960; # 40GB
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-id/ata-LK0800GEYMU_BTHC623100VD800NGN-part2"; }
      { device = "/dev/disk/by-id/ata-INTEL_SSDSC2BX800G4_BTHC548502D3800NGN-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c500a0bb63db-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c500b84b79eb-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5007f943977-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5007ef5219f-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5006bc7ed5b-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5006bd3cc3b-part2"; }
    ];
  };
}
