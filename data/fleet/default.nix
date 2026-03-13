let
  hosts = (import ./hosts/lab.nix) // (import ./hosts/infra.nix);
  devices = (import ./devices/switches.nix) // (import ./devices/aps.nix);
in {
  # The topology subset is what the NixOS module system consumes via
  # psyclyx.topology. Adding fields here won't break module eval.
  # Everything else (devices, groups, secrets) is fleet-only data.
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
