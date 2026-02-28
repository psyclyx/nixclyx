{
  path = ["psyclyx" "nixos" "hosts" "lab-4"];
  variant = ["psyclyx" "nixos" "host"];
  config = {lib, ...}: {
    networking.hostName = "lab-4";
    psyclyx.nixos = {
      filesystems.layouts.zfs-pool = {
        enable = true;
        hostId = "9924de5f";
        boot.UUID = "CF86-D5FF";
        arc.maxBytes = 85899345920; # 80GB
      };
    };

    swapDevices = [
      { device = "/dev/disk/by-id/ata-LK0800GEYMU_BTHC6403075M800NGN-part2"; }
      { device = "/dev/disk/by-id/ata-LK0800GEYMU_BTHC6230013F800NGN-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5007f20d437-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5007f891413-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5008f445f47-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c50096200287-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c5006bc3a44b-part2"; }
      { device = "/dev/disk/by-id/scsi-35000c500971c650f-part2"; }
    ];
  };
}
