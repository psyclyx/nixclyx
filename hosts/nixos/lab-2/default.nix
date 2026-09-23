{ ... }:
{
  networking.hostName = "lab-2";
  psyclyx.nixos = {
    role = "server";

    # See lab-1's notes on the same block — same DL360 Gen9 hardware,
    # same NFS-root layout, same firewall convention.
    network.topology = {
      enable = true;
      defaultNetwork = "main";
    };
    network.interfaces.initrd = {
      enable = true;
      kernelModules = [ "tg3" ];
    };
    network.firewall.input.lan.policy = "accept";
    # Lab hosts trust the lab fabric (eno49np0): the hypervisor↔
    # storage-host data path. Storage VLAN stays default-drop to keep
    # iSCSI rack-local.
    network.firewall.input.lab-transit.policy = "accept";
    hardware.presets.hpe.dl360-gen9.enable = true;
    filesystems.nfs-root.enable = true;
  };
}
