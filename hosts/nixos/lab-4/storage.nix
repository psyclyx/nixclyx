{ ... }:
{
  psyclyx.nixos = {
    # NFS shares + iSCSI targets/initiators projected from egregore data.
    topology.nfs.enable = true;
    topology.iscsi.enable = true;

    # OpenBao moved to iyr — iyr's seal-oracle module is extended with
    # userpass auth + KV, so it doubles as the fleet OpenBao. lab-4
    # has nothing OpenBao-related anymore; if PKI consumers ever land
    # here (Patroni etc.), they reach iyr at 10.0.25.1:8200 (or via
    # the CRS326's L3 routing from the lab VLAN).
  };
}
