pkgs:
pkgs.buildEnv {
  name = "env-network-admin";
  paths = [
    pkgs.iproute2
    pkgs.bind # dig, nslookup
    pkgs.ethtool
    pkgs.mtr
    pkgs.traceroute
    pkgs.iperf3
  ];
  meta.description = "Network administration and diagnostic tools";
}
