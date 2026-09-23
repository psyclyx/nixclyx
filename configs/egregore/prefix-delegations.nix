# Onward IPv6 prefix delegation.
#
# iyr receives a /60 from Xfinity and hands the upper half to mdf-agg01,
# which carves /64s from it for the VLANs it routes. The lower half
# stays with iyr's own networkd for anything it still gateways — a hard
# bit boundary, so the two allocators can't collide.
#
# The prefix itself appears nowhere: Comcast changes it, and a design
# that is correct until they do is a scheduled outage.
{
  gate = "always";
  config.entities = {
    mdf-agg01-pd = {
      
      refs = { from = "iyr"; to = "mdf-agg01"; over = "core-transit"; };
      prefix-delegation = { subnetId = 1; prefixLength = 61; };
    };
  };
}
