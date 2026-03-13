let
  hosts = (import ./hosts/lab.nix) // (import ./hosts/infra.nix);
  devices = (import ./devices/switches.nix) // (import ./devices/aps.nix);
in {
  topology = {
    conventions = {
      gatewayOffset = 1;
      transitVlan = 250;
    };
    domains = import ./domains.nix;
    wireguard = import ./wireguard.nix;
    ipv6UlaPrefix = "fd9a:e830:4b1e";
    inherit hosts;
    haGroups = import ./ha.nix;
    networks = import ./networks.nix;
  };

  inherit hosts devices;
  groups = import ./groups.nix;
}
