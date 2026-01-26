{ ... }:
{
  config = {
    networking.hostName = "lab-1";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "4dbf5223-00ae-4cff-ad70-47e5e09d66e0";
        boot = "B320-71E8";
      };
    };
  };
}
