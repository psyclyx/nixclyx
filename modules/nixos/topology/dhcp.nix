{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  fleet = config.psyclyx.fleet;

  cfg = config.psyclyx.topology.dhcp;

  labServers = lib.sort (a: b: a.name < b.name) (lib.mapAttrsToList (name: _host: {
    inherit name;
  }) (lib.filterAttrs (_: host: host.mac != {}) topo.hosts));

  labServersOnNetwork = networkName:
    builtins.filter (s: topo.hosts.${s.name}.interfaces ? ${networkName}) labServers;

  mkSubnet4 = _poolName: pool: let
    net = fleet.networks.${pool.network};
  in {
    id = net.vlan;
    subnet = "${net.prefix}.0/${toString net.prefixLen}";
    pools = [{pool = "${pool.ipv4Range.start} - ${pool.ipv4Range.end}";}];
    "option-data" = [
      { name = "routers"; data = net.gateway4; }
      { name = "domain-name-servers"; data = net.gateway4; }
      { name = "domain-name"; data = net.zoneName; }
      { name = "domain-search"; data = "${net.zoneName}, ${topo.domains.home}, ${topo.domains.internal}"; }
    ];
    ddns-qualifying-suffix = "${net.zoneName}.";
    reservations = let
      servers = labServersOnNetwork pool.network;
      labReservations = map (s: {
        "hw-address" = fleet.hostMacForNetwork s.name pool.network;
        "ip-address" = fleet.hostAddress s.name pool.network;
        hostname = s.name;
      }) servers;
    in
      labReservations ++ pool.extraReservations;
  };

  mkSubnet6 = _poolName: pool: let
    net = fleet.networks.${pool.network};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
  in {
    id = net.vlan;
    subnet = net.subnet6;
    interface = "${cfg.interface}.${toString net.vlan}";
    pools = [{pool = "${prefix6}::${pool.ipv6Suffix.start} - ${prefix6}::${pool.ipv6Suffix.end}";}];
    "option-data" = [
      { name = "dns-servers"; data = net.gateway6; }
      { name = "domain-search"; data = "${net.zoneName}, ${topo.domains.home}, ${topo.domains.internal}"; }
    ];
    ddns-qualifying-suffix = "${net.zoneName}.";
    reservations = let
      servers = labServersOnNetwork pool.network;
      labReservations = map (s: {
        "hw-address" = fleet.hostMacForNetwork s.name pool.network;
        "ip-addresses" = [( fleet.hostAddress6 s.name pool.network )];
        hostname = s.name;
      }) servers;
    in
      labReservations;
  };

  ipv6Pools = lib.filterAttrs (_: pool: pool.ipv6) cfg.pools;

  poolVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: pool: topo.networks.${pool.network}.vlan) cfg.pools);

  interfaces = map (id: "${cfg.interface}.${toString id}") poolVlans;
in {
  options.psyclyx.topology.dhcp = {
    enable = lib.mkEnableOption "DHCP server derived from topology";

    pools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          network = lib.mkOption {
            type = lib.types.str;
            description = "Topology network name for this pool.";
          };
          ipv4Range = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; description = "First IPv4 address in pool."; };
                end = lib.mkOption { type = lib.types.str; description = "Last IPv4 address in pool."; };
              };
            };
            description = "IPv4 DHCP pool range.";
          };
          ipv6 = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to generate a DHCPv6 pool for this network.";
          };
          ipv6Suffix = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; default = "100"; description = "Start host suffix for the IPv6 pool (appended to network prefix6)."; };
                end = lib.mkOption { type = lib.types.str; default = "1ff"; description = "End host suffix for the IPv6 pool (appended to network prefix6)."; };
              };
            };
            default = {};
            description = "IPv6 pool host-part suffix range (default ::100 - ::1ff).";
          };
          extraReservations = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [];
            description = "Additional DHCPv4 reservations (Kea format: hw-address, ip-address, hostname).";
          };
        };
      });
      default = {};
      description = "DHCP pool definitions per network.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "bond0";
      description = "Base interface name (VLAN sub-interfaces are derived as interface.vlanId).";
    };

    extraDhcp4 = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra attributes merged into the DHCPv4 settings (e.g. hooks-libraries).";
    };

    extraDhcp6 = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra attributes merged into the DHCPv6 settings (e.g. hooks-libraries).";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.pools != {}) {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp4.leases";
        };
        valid-lifetime = 43200;
        renew-timer = 10800;
        rebind-timer = 21600;
        subnet4 = lib.mapAttrsToList mkSubnet4 cfg.pools;
      } // cfg.extraDhcp4;
    };

    services.kea.dhcp6 = lib.mkIf (ipv6Pools != {}) {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp6.leases";
        };
        valid-lifetime = 43200;
        renew-timer = 10800;
        rebind-timer = 21600;
        subnet6 = lib.mapAttrsToList mkSubnet6 ipv6Pools;
        host-reservation-identifiers = ["hw-address" "duid"];
        mac-sources = ["ipv6-link-local"];
      } // cfg.extraDhcp6;
    };
  };
}
