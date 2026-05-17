# iSCSI LUNs — zvols exported by storage hosts to consumers.
#
# Each entry is a single LUN. The producer (`refs.producer`) hosts the
# zvol; the consumers attach over the network named in `lun.network`.
# IQNs, target ACLs, and initiator initramfs config all derive from
# these entries via the iscsi projection.
#
# Currently empty. Hosts PXE-boot from iyr and mount /nix and /persist
# over NFS (see nfs-exports.nix), so there are no per-host root LUNs.
# This file will fill in when we start spinning up VMs — each VM's
# block disk becomes a `lun` entity here.
{
  gate = "always";
  config = {
    entities = { };
  };
}
