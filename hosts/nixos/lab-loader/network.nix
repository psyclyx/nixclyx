# Lab-loader networking: DHCP on whatever ethernet shows up.
#
# Stage-2 only — the chain unit runs in stage-2 as well, so initrd
# networking isn't needed (no NFS-root, no in-initrd fetches). Match
# pattern is direct systemd.network because the loader has no
# egregore entity to project from.
{ ... }:
{
  systemd.network.networks."10-lab-loader" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseDomains = true;
      UseDNS = true;
      # Match how Kea keys reservations: per-host reservations on iyr
      # use `hw-address` (MAC). With the default DUID-based client-id,
      # Kea fails to match the reservation and hands out a pool IP.
      ClientIdentifier = "mac";
    };
  };
}
