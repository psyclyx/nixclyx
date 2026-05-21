# Lab-loader networking: DHCP on whatever ethernet shows up.
#
# Kernel ip=dhcp on the cmdline brings the link up before systemd
# starts (clevis-tang in the spec interpreter needs net up before
# stage-1 fully runs). systemd-networkd-in-initrd then takes over
# for the steady state.
{ ... }:
{
  # Initrd-side networking — what the chain script needs to fetch
  # the spec and JWE blobs before kexec.
  boot.initrd.systemd.network.enable = true;
  boot.initrd.systemd.network.networks."10-lab-loader" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseDomains = true;
      UseDNS = true;
      # Match how Kea keys reservations: per-host reservations on
      # iyr's DHCP server use `hw-address` (MAC). With the default
      # DUID-based client-id, Kea fails to match the reservation and
      # hands out a pool IP — lab-3 ends up at 10.0.210.240 instead
      # of its reserved 10.0.210.13.
      ClientIdentifier = "mac";
    };
  };
  boot.initrd.systemd.network.wait-online.enable = true;

  # Stage-2 networking — kicks in when initrd falls through to the
  # netboot squashfs system (chain script bailed without kexec'ing).
  # Without this, lab-3 lands at a login prompt with no network and
  # is only debuggable via console.
  systemd.network.enable = true;
  networking.useNetworkd = true;
  systemd.network.networks."10-lab-loader" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseDomains = true;
      UseDNS = true;
      # Match how Kea keys reservations: per-host reservations on
      # iyr's DHCP server use `hw-address` (MAC). With the default
      # DUID-based client-id, Kea fails to match the reservation and
      # hands out a pool IP — lab-3 ends up at 10.0.210.240 instead
      # of its reserved 10.0.210.13.
      ClientIdentifier = "mac";
    };
  };
  networking.useDHCP = false;  # avoid the legacy dhcpcd
}
