{config, lib, ...}: let
  eg = config.psyclyx.egregore;

  cfg = config.psyclyx.nixos.services.dhcp;

  hosts = lib.filterAttrs (_: e: e.type == "host") eg.entities;

  # Hosts with MAC addresses that have an interface on a given network.
  managedHostsOnNetwork = network:
    lib.sort builtins.lessThan
      (builtins.attrNames (lib.filterAttrs (_: e:
        e.host.mac != {} && e.host.interfaces ? ${network}
      ) hosts));

  # MAC address for a host's physical interface on a network.
  hostMacForNetwork = hostname: network: let
    h = eg.entities.${hostname}.host;
    iface = h.interfaces.${network};
    physDev = iface.device;
  in h.mac.${physDev};

  mkSubnet4 = _poolName: pool: let
    net = eg.entities.${pool.network};
    na = net.attrs;
  in {
    id = na.vlan;
    subnet = "${na.prefix}.0/${toString na.prefixLen}";
    pools = [{pool = "${pool.ipv4Range.start} - ${pool.ipv4Range.end}";}];
    "option-data" = [
      { name = "routers"; data = na.gateway4; }
      { name = "domain-name-servers"; data = na.gateway4; }
      { name = "domain-name"; data = na.zoneName; }
      { name = "domain-search"; data = "${na.zoneName}, ${eg.domains.home}, ${eg.domains.internal}"; }
    ];
    ddns-qualifying-suffix = "${na.zoneName}.";
    reservations = let
      servers = managedHostsOnNetwork pool.network;
      labReservations = map (name: {
        "hw-address" = hostMacForNetwork name pool.network;
        "ip-address" = eg.entities.${name}.host.addresses.${pool.network}.ipv4;
        hostname = name;
      }) servers;
    in
      labReservations ++ pool.extraReservations;
  };

  mkSubnet6 = _poolName: pool: let
    net = eg.entities.${pool.network};
    na = net.attrs;
    prefix6 = "${eg.ipv6UlaPrefix}:${net.network.ulaSubnetHex}";
  in {
    id = na.vlan;
    subnet = na.subnet6;
    interface = "${cfg.interface}.${toString na.vlan}";
    pools = [{pool = "${prefix6}::${pool.ipv6Suffix.start} - ${prefix6}::${pool.ipv6Suffix.end}";}];
    "option-data" = [
      { name = "dns-servers"; data = na.gateway6; }
      { name = "domain-search"; data = "${na.zoneName}, ${eg.domains.home}, ${eg.domains.internal}"; }
    ];
    ddns-qualifying-suffix = "${na.zoneName}.";
    reservations = let
      servers = managedHostsOnNetwork pool.network;
    in map (name: {
      "hw-address" = hostMacForNetwork name pool.network;
      "ip-addresses" = [eg.entities.${name}.host.addresses.${pool.network}.ipv6];
      hostname = name;
    }) servers;
  };

  ipv6Pools = lib.filterAttrs (_: pool: pool.ipv6) cfg.pools;

  poolVlans = lib.sort builtins.lessThan
    (lib.mapAttrsToList (_: pool: eg.entities.${pool.network}.network.vlan) cfg.pools);

  interfaces = map (id: "${cfg.interface}.${toString id}") poolVlans;
in {
  options.psyclyx.nixos.services.dhcp = {
    enable = lib.mkEnableOption "DHCP server derived from egregore entities";

    pools = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          network = lib.mkOption { type = lib.types.str; };
          ipv4Range = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; };
                end = lib.mkOption { type = lib.types.str; };
              };
            };
          };
          ipv6 = lib.mkOption { type = lib.types.bool; default = true; };
          ipv6Suffix = lib.mkOption {
            type = lib.types.submodule {
              options = {
                start = lib.mkOption { type = lib.types.str; default = "100"; };
                end = lib.mkOption { type = lib.types.str; default = "1ff"; };
              };
            };
            default = {};
          };
          extraReservations = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            default = [];
          };
        };
      });
      default = {};
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "bond0";
    };

    extraDhcp4 = lib.mkOption { type = lib.types.attrs; default = {}; };
    extraDhcp6 = lib.mkOption { type = lib.types.attrs; default = {}; };
  };

  config = lib.mkIf (cfg.enable && cfg.pools != {}) {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config.interfaces = interfaces;
        lease-database = { type = "memfile"; persist = true; name = "/var/lib/kea/dhcp4.leases"; };
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
        lease-database = { type = "memfile"; persist = true; name = "/var/lib/kea/dhcp6.leases"; };
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
