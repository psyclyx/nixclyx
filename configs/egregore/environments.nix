# Environments — logical deployment contexts.
#
# Named env-* to avoid collision with network entities (e.g. VLANs of the
# same name). The VLAN is the L2/L3 segment; the environment is the
# logical context. Currently empty — stage was decommissioned and prod
# was never wired up. Add new env entities here as services need them.
{
  gate = "always";
  config = {
    entities = {};
  };
}
