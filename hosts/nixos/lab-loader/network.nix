# Lab-loader networking: DHCP on whatever ethernet shows up.
#
# Kernel ip=dhcp on the cmdline brings the link up before systemd
# starts (clevis-tang in the spec interpreter needs net up before
# stage-1 fully runs). systemd-networkd-in-initrd then takes over
# for the steady state.
{ ... }:
{
  boot.initrd.systemd.network.enable = true;
  boot.initrd.systemd.network.networks."10-lab-loader" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseDomains = true;
      UseDNS = true;
    };
  };
  # Wait-online: we want the spec fetch to actually have a route.
  boot.initrd.systemd.network.wait-online.enable = true;
}
