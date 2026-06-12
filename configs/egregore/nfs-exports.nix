# Stand-alone NFS exports — paths NOT backed by a zfs-dataset entity
# auto-derived elsewhere.
#
# ZFS-dataset-backed exports for shared /nix and per-host /persist
# come from topology/storage.nix via host refs.{nixDataset,
# persistDataset}. Everything else lives here.
{
  gate = "always";
  config.entities = {
    # Lab-4's vault/nas — general-purpose NAS share for off-rack
    # clients. krb5i auth: sigil mounts via main VLAN, KDC at
    # tleilax.vpn issues nfs/lab-4.main.apt.psyclyx.net tickets and
    # the export checks them.
    nfs-nas = {
      type = "nfs-export";
      refs.producer = "lab-4";
      nfs-export = {
        path = "/srv/nfs/nas";
        # Mount target + server bind on lab VLAN: lab-4's eno49np0
        # (10G) is here, and mdf-agg01's L3 hw offload routes main↔lab
        # at line rate. Storage VLAN stays isolated (rack-internal,
        # unauth) per the lab-v3 design — off-rack clients route via
        # lab.
        network = "lab";
        # Sigil has no lab-VLAN address. Its source IP for traffic to
        # 10.0.210.0/24 stays on main (10.0.10.100) — its only
        # routable interface — so the export ACL keys on main.
        consumerNetwork = "main";
        consumers = [ "sigil" ];
        sec = "krb5i";
        mountAt = "/mnt/nas";
        readOnly = false;
      };
    };
  };
}
