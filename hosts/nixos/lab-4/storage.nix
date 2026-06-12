{ ... }:
{
  psyclyx.nixos = {
    # NFS shares + iSCSI targets/initiators projected from egregore data.
    # NFS projection is data-driven (no enable toggle); iscsi/storage
    # still gate on these.
    derived.iscsi.enable = true;
    derived.storage.enable = true;

    # OpenBao moved to iyr — iyr's seal-oracle module is extended with
    # userpass auth + KV, so it doubles as the fleet OpenBao. lab-4
    # has nothing OpenBao-related anymore; if PKI consumers ever land
    # here (Patroni etc.), they reach iyr at 10.0.25.1:8200 (or via
    # the CRS326's L3 routing from the lab VLAN).
  };
}
