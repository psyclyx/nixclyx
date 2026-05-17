# High-availability groups.
#
# The lab/lab-stage cluster groups were removed in the 2026 storage-host
# rework: lab-1..3 are powered off and lab-4 is being repurposed as the
# ZFS/iSCSI host running single-node PKI (no Raft, no VIP). When clustered
# services come back, add new ha-group entities here.
{
  gate = "always";
  config = {
    entities = {};
  };
}
