{
  config,
  lib,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;
  conventions = topo.conventions;

  cfg = config.psyclyx.topology.dhcp;

  # Lab servers sorted by index (for stable reservation ordering).
  labServers = lib.sort (a: b: a.n < b.n) (lib.mapAttrsToList (name: host: {
    inherit name;
    n = host.labIndex;
    macs = host.mac;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  # Build a Kea DHCPv4 subnet from a pool definition.
  mkSubnet4 = _poolName: pool: let
    net = dt.networks.${pool.network};
  in {
    id = net.vlan;
    subnet = "${net.prefix}.0/${toString net.prefixLen}";
    pools = [{pool = "${pool.ipv4Range.start} - ${pool.ipv4Range.end}";}];
    "option-data" = [
      { name = "routers"; data = net.gateway4; }
      { name = "domain-name-servers"; data = net.gateway4; }
      { name = "domain-name"; data = net.zoneName; }
      { name = "domain-search"; data = "${net.zoneName}, ${topo.domains.home}"; }
    ];
    reservations =
      if net.labIface == null
      then []
      else
        map (s: {
          "hw-address" = s.macs.${net.labIface};
          "ip-address" = "${net.prefix}.${toString (conventions.hostBaseOffset + s.n)}";
          hostname = s.name;
        })
        labServers;
  };

  # Build a Kea DHCPv6 subnet from a pool definition.
  mkSubnet6 = _poolName: pool: let
    net = dt.networks.${pool.network};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
  in {
    id = net.vlan;
    subnet = net.subnet6;
    pools = [{pool = "${prefix6}::${pool.ipv6Suffix.start} - ${prefix6}::${pool.ipv6Suffix.end}";}];
    "option-data" = [
      { name = "dns-servers"; data = net.gateway6; }
      { name = "domain-search"; data = "${net.zoneName}, ${topo.domains.home}"; }
    ];
    reservations =
      if net.labIface == null
      then []
      else
        map (s: {
          "hw-address" = s.macs.${net.labIface};
          "ip-addresses" = ["${prefix6}::${dt.utils.intToHex (conventions.hostBaseOffset + s.n)}"];
          hostname = s.name;
        })
        labServers;
  };

  # Pools that have IPv6 enabled.
  ipv6Pools = lib.filterAttrs (_: pool: pool.ipv6) cfg.pools;

  # Sorted VLAN IDs from the pools (for deterministic interface ordering).
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
        valid-lifetime = 3600;
        renew-timer = 900;
        rebind-timer = 1800;
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
        valid-lifetime = 3600;
        renew-timer = 900;
        rebind-timer = 1800;
        subnet6 = lib.mapAttrsToList mkSubnet6 ipv6Pools;
        host-reservation-identifiers = ["hw-address" "duid"];
        mac-sources = ["ipv6-link-local"];
      } // cfg.extraDhcp6;
    };
  };
}
