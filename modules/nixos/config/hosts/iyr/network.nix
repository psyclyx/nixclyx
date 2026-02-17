{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;

  # Derive VLAN lists from topology
  dhcpVlans = lib.sort builtins.lessThan (lib.mapAttrsToList (_: net: net.vlan) topo.networks);
  transitVlan = 250;
  vlanIds = dhcpVlans ++ [transitVlan];

  vlanIface = iface: id: "${iface}.${builtins.toString id}";
  vlanNetdev = iface: id: {
    netdevConfig = {
      Name = vlanIface iface id;
      Kind = "vlan";
    };
    vlanConfig.Id = id;
  };
  vlanNetdevPair = iface: id:
    lib.nameValuePair
    "31-${vlanIface iface id}"
    (vlanNetdev iface id);

  # Derive lab server list from topology (sorted by index for stable ordering)
  labServers = lib.sort (a: b: a.n < b.n) (lib.mapAttrsToList (name: host: {
    inherit name;
    n = host.labIndex;
    interfaces = host.mac;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  # Derive VLAN → name/interface/subnet-id maps from topology
  vlanZoneMap = builtins.listToAttrs (lib.mapAttrsToList (name: net:
    lib.nameValuePair (toString net.vlan) name
  ) topo.networks);

  vlanIfaceMap = builtins.listToAttrs (lib.mapAttrsToList (_: net:
    lib.nameValuePair (toString net.vlan) net.labIface
  ) topo.networks);

  ipv6SubnetMap = builtins.listToAttrs (lib.mapAttrsToList (_: net:
    lib.nameValuePair (toString net.vlan) net.ipv6PdSubnetId
  ) topo.networks);

  # IPv6 ULA addressing (derived from topology)
  ulaPrefix = topo.ipv6UlaPrefix;
  ulaReverseBase = let
    stripped = lib.replaceStrings [":"] [""] ulaPrefix;
    chars = lib.stringToCharacters stripped;
    reversed = lib.reverseList chars;
  in lib.concatStringsSep "." reversed;

  intToHex = n: let
    hexDigits = ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "a" "b" "c" "d" "e" "f"];
    toHexDigit = d: builtins.elemAt hexDigits d;
    go = x:
      if x < 16
      then toHexDigit x
      else (go (x / 16)) + toHexDigit (lib.mod x 16);
  in
    go n;

  vlanHex = builtins.listToAttrs (map (id: {
      name = toString id;
      value = intToHex id;
    })
    dhcpVlans);

  hexToReverseNibbles = hex: let
    padded = lib.fixedWidthString 4 "0" hex;
    chars = lib.stringToCharacters padded;
    reversed = lib.reverseList chars;
  in
    lib.concatStringsSep "." reversed;

  vlanIp6Reverse = builtins.listToAttrs (map (id: {
      name = toString id;
      value = hexToReverseNibbles vlanHex.${toString id};
    })
    dhcpVlans);

  hostReverseNibbles = hexStr: let
    padded = lib.fixedWidthString 16 "0" hexStr;
    chars = lib.stringToCharacters padded;
    reversed = lib.reverseList chars;
  in
    lib.concatStringsSep "." reversed;

  mkForwardZone = vlanId: let
    vlanStr = toString vlanId;
    zoneName = vlanZoneMap.${vlanStr};
    fqZone = "${zoneName}.home.psyclyx.net";
    prefix = "10.0.${vlanStr}";
    hex = vlanHex.${vlanStr};
    ifaceName = vlanIfaceMap.${vlanStr};
    gatewayRecord = "iyr.${fqZone}. IN A ${prefix}.1";
    gatewayRecord6 = "iyr.${fqZone}. IN AAAA ${ulaPrefix}:${hex}::1";
    serverRecords =
      if ifaceName == null
      then []
      else
        map (s: "${s.name}.${fqZone}. IN A ${prefix}.${toString (10 + s.n)}")
        labServers;
    serverRecords6 =
      if ifaceName == null
      then []
      else
        map (s: "${s.name}.${fqZone}. IN AAAA ${ulaPrefix}:${hex}::${intToHex (10 + s.n)}")
        labServers;
  in {
    name = fqZone;
    value = {
      type = "static";
      records = [gatewayRecord gatewayRecord6] ++ serverRecords ++ serverRecords6;
    };
  };

  mkReverseZone = vlanId: let
    vlanStr = toString vlanId;
    zoneName = vlanZoneMap.${vlanStr};
    fqZone = "${zoneName}.home.psyclyx.net";
    reverseZone = "${vlanStr}.0.10.in-addr.arpa";
    ifaceName = vlanIfaceMap.${vlanStr};
    gatewayPtr = "1.${reverseZone}. IN PTR iyr.${fqZone}.";
    serverPtrs =
      if ifaceName == null
      then []
      else
        map (s: "${toString (10 + s.n)}.${reverseZone}. IN PTR ${s.name}.${fqZone}.")
        labServers;
  in {
    name = reverseZone;
    value = {
      type = "static";
      records = [gatewayPtr] ++ serverPtrs;
    };
  };

  mkIp6ReverseZone = vlanId: let
    vlanStr = toString vlanId;
    zoneName = vlanZoneMap.${vlanStr};
    fqZone = "${zoneName}.home.psyclyx.net";
    reverseZone = "${vlanIp6Reverse.${vlanStr}}.${ulaReverseBase}.ip6.arpa";
    ifaceName = vlanIfaceMap.${vlanStr};
    gatewayPtr = "${hostReverseNibbles "1"}.${reverseZone}. IN PTR iyr.${fqZone}.";
    serverPtrs =
      if ifaceName == null
      then []
      else
        map (s: "${hostReverseNibbles (intToHex (10 + s.n))}.${reverseZone}. IN PTR ${s.name}.${fqZone}.")
        labServers;
  in {
    name = reverseZone;
    value = {
      type = "static";
      records = [gatewayPtr] ++ serverPtrs;
    };
  };

  localZones = builtins.listToAttrs (
    [
      {
        name = "home.psyclyx.net";
        value = {
          type = "static";
          records = [];
        };
      }
    ]
    ++ (map mkForwardZone dhcpVlans)
    ++ (map mkReverseZone dhcpVlans)
    ++ (map mkIp6ReverseZone dhcpVlans)
  );

  protectedHostnames = ["iyr"] ++ map (s: s.name) labServers;

  unboundControl = "${pkgs.unbound}/bin/unbound-control";

  keaDnsHookScript = pkgs.writeShellScript "kea-dns-hook" ''
    DOMAIN="home.psyclyx.net"
    STATE_DIR="/run/kea-dns-state"

    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"

    get_zone() {
      case "$1" in
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList (id: zone: "${id}) echo \"${zone}\" ;;") vlanZoneMap)}
        *) echo "" ;;
      esac
    }

    sanitize_hostname() {
      echo "$1" | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]' | ${pkgs.gnused}/bin/sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//'
    }

    is_protected() {
      case "$1" in
        ${lib.concatStringsSep "|" protectedHostnames}) return 0 ;;
        *) return 1 ;;
      esac
    }

    rebuild_forward() {
      local hostname="$1" zone="$2" fqdn="$3"
      ${unboundControl} local_data_remove "''${fqdn}." || true
      for f in "''${STATE_DIR}/''${hostname}.''${zone}."*; do
        [ -f "$f" ] || continue
        local proto_suffix="''${f##*.}"
        local addr
        addr=$(<"$f")
        case "$proto_suffix" in
          v4) ${unboundControl} local_data "''${fqdn}. 300 IN A ''${addr}" || true ;;
          v6) ${unboundControl} local_data "''${fqdn}. 300 IN AAAA ''${addr}" || true ;;
        esac
      done
    }

    process_lease() {
      local proto="$1" action="$2" subnet_id="$3" address="$4" hostname_raw="$5"

      local ZONE
      ZONE=$(get_zone "$subnet_id")
      [ -z "$ZONE" ] && return

      local FQZONE="''${ZONE}.''${DOMAIN}"
      local HOSTNAME
      HOSTNAME=$(sanitize_hostname "$hostname_raw")
      [ -z "$HOSTNAME" ] && return

      is_protected "$HOSTNAME" && return

      local FQDN="''${HOSTNAME}.''${FQZONE}"
      local STATE_FILE="''${STATE_DIR}/''${HOSTNAME}.''${ZONE}.''${proto}"

      case "$action" in
        add)
          echo "$address" > "$STATE_FILE"
          rebuild_forward "$HOSTNAME" "$ZONE" "$FQDN"
          if [ "$proto" = "v4" ]; then
            local LAST_OCTET THIRD_OCTET PTR_NAME
            LAST_OCTET=$(echo "$address" | ${pkgs.coreutils}/bin/cut -d. -f4)
            THIRD_OCTET=$(echo "$address" | ${pkgs.coreutils}/bin/cut -d. -f3)
            PTR_NAME="''${LAST_OCTET}.''${THIRD_OCTET}.0.10.in-addr.arpa"
            ${unboundControl} local_data "''${PTR_NAME}. 300 IN PTR ''${FQDN}." || true
          else
            local PTR_NAME
            PTR_NAME=$(${pkgs.python3}/bin/python3 -c "import ipaddress; print(ipaddress.ip_address('$address').reverse_pointer)")
            ${unboundControl} local_data "''${PTR_NAME}. 300 IN PTR ''${FQDN}." || true
          fi
          ;;
        remove)
          ${pkgs.coreutils}/bin/rm -f "$STATE_FILE"
          rebuild_forward "$HOSTNAME" "$ZONE" "$FQDN"
          if [ "$proto" = "v4" ]; then
            local LAST_OCTET THIRD_OCTET PTR_NAME
            LAST_OCTET=$(echo "$address" | ${pkgs.coreutils}/bin/cut -d. -f4)
            THIRD_OCTET=$(echo "$address" | ${pkgs.coreutils}/bin/cut -d. -f3)
            PTR_NAME="''${LAST_OCTET}.''${THIRD_OCTET}.0.10.in-addr.arpa"
            ${unboundControl} local_data_remove "''${PTR_NAME}." || true
          else
            local PTR_NAME
            PTR_NAME=$(${pkgs.python3}/bin/python3 -c "import ipaddress; print(ipaddress.ip_address('$address').reverse_pointer)")
            ${unboundControl} local_data_remove "''${PTR_NAME}." || true
          fi
          ;;
      esac
    }

    EVENT="$1"

    case "$EVENT" in
      lease4_renew|lease4_committed)
        process_lease "v4" "add" "$SUBNET4_ID" "$LEASE4_ADDRESS" "$LEASE4_HOSTNAME"
        ;;
      lease4_release|lease4_expire)
        process_lease "v4" "remove" "$SUBNET4_ID" "$LEASE4_ADDRESS" "$LEASE4_HOSTNAME"
        ;;
      lease6_renew|lease6_rebind)
        process_lease "v6" "add" "$SUBNET6_ID" "$LEASE6_ADDRESS" "$LEASE6_HOSTNAME"
        ;;
      lease6_release|lease6_expire)
        process_lease "v6" "remove" "$SUBNET6_ID" "$LEASE6_ADDRESS" "$LEASE6_HOSTNAME"
        ;;
      leases6_committed)
        i=0
        while [ "$i" -lt "''${LEASES6_SIZE:-0}" ]; do
          addr_var="LEASES6_AT''${i}_ADDRESS"
          hostname_var="LEASES6_AT''${i}_HOSTNAME"
          addr="''${!addr_var}"
          hostname="''${!hostname_var}"
          [ -n "$addr" ] && [ -n "$hostname" ] && \
            process_lease "v6" "add" "$SUBNET6_ID" "$addr" "$hostname"
          i=$((i + 1))
        done
        i=0
        while [ "$i" -lt "''${DELETED_LEASES6_SIZE:-0}" ]; do
          addr_var="DELETED_LEASES6_AT''${i}_ADDRESS"
          hostname_var="DELETED_LEASES6_AT''${i}_HOSTNAME"
          addr="''${!addr_var}"
          hostname="''${!hostname_var}"
          [ -n "$addr" ] && [ -n "$hostname" ] && \
            process_lease "v6" "remove" "$SUBNET6_ID" "$addr" "$hostname"
          i=$((i + 1))
        done
        ;;
    esac

    exit 0
  '';

  mkSubnet = vlanId: let
    prefix = "10.0.${toString vlanId}";
    ifaceName = vlanIfaceMap.${toString vlanId} or null;
    zoneName = "${vlanZoneMap.${toString vlanId}}.home.psyclyx.net";
  in {
    id = vlanId;
    subnet = "${prefix}.0/24";
    pools = [{pool = "${prefix}.100 - ${prefix}.199";}];
    "option-data" = [
      {
        name = "routers";
        data = "${prefix}.1";
      }
      {
        name = "domain-name-servers";
        data = "${prefix}.1";
      }
      {
        name = "domain-name";
        data = zoneName;
      }
      {
        name = "domain-search";
        data = "${zoneName}, home.psyclyx.net";
      }
    ];
    reservations =
      if ifaceName == null
      then []
      else
        map (s: {
          "hw-address" = s.interfaces.${ifaceName};
          "ip-address" = "${prefix}.${toString (10 + s.n)}";
          hostname = s.name;
        })
        labServers;
  };

  mkSubnet6 = vlanId: let
    vlanStr = toString vlanId;
    hex = vlanHex.${vlanStr};
    prefix = "${ulaPrefix}:${hex}";
    ifaceName = vlanIfaceMap.${vlanStr};
    zoneName = "${vlanZoneMap.${vlanStr}}.home.psyclyx.net";
  in {
    id = vlanId;
    subnet = "${prefix}::/64";
    pools = [{pool = "${prefix}::100 - ${prefix}::1ff";}];
    "option-data" = [
      {
        name = "dns-servers";
        data = "${prefix}::1";
      }
      {
        name = "domain-search";
        data = "${zoneName}, home.psyclyx.net";
      }
    ];
    reservations =
      if ifaceName == null
      then []
      else
        map (s: {
          "hw-address" = s.interfaces.${ifaceName};
          "ip-addresses" = ["${prefix}::${intToHex (10 + s.n)}"];
          hostname = s.name;
        })
        labServers;
  };
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    networking.firewall = {
      enable = true;
      trustedInterfaces =
        ["bond0"]
        ++ map (id: "bond0.${toString id}") dhcpVlans;
    };

    networking.nat = {
      enable = true;
      externalInterface = "bond0.${toString transitVlan}";
      internalInterfaces = map (id: "bond0.${toString id}") dhcpVlans;
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

    psyclyx.nixos.services.kea = {
      enable = true;
      interfaces = map (id: "bond0.${toString id}") dhcpVlans;
      subnets = map mkSubnet dhcpVlans;
      hooksLibraries = [
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
          parameters = {
            name = "${keaDnsHookScript}";
            sync = false;
          };
        }
      ];
    };

    services.kea.dhcp6 = {
      enable = true;
      settings = {
        interfaces-config.interfaces = map (id: "bond0.${toString id}") dhcpVlans;
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp6.leases";
        };
        valid-lifetime = 3600;
        renew-timer = 900;
        rebind-timer = 1800;
        subnet6 = map mkSubnet6 dhcpVlans;
        hooks-libraries = [
          {
            library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
            parameters = {
              name = "${keaDnsHookScript}";
              sync = false;
            };
          }
        ];
        host-reservation-identifiers = ["hw-address" "duid"];
        mac-sources = ["ipv6-link-local"];
      };
    };

    psyclyx.nixos.network.dns.resolver.localZones = localZones;

    services.unbound.localControlSocketPath = "/run/unbound/unbound.ctl";

    systemd.services.kea-dhcp4-server = {
      after = ["unbound.service"];
      serviceConfig.SupplementaryGroups = ["unbound"];
    };

    systemd.services.kea-dhcp6-server = {
      after = ["unbound.service"];
      serviceConfig.SupplementaryGroups = ["unbound"];
    };

    systemd.tmpfiles.rules = [
      "d /run/kea-dns-state 0755 kea kea -"
    ];

    systemd.network = {
      netdevs =
        {
          "30-bond0" = {
            netdevConfig = {
              Name = "bond0";
              Kind = "bond";
            };
            bondConfig = {
              Mode = "802.3ad";
              LACPTransmitRate = "fast";
              TransmitHashPolicy = "layer3+4";
              MIIMonitorSec = "1s";
            };
          };
        }
        // (builtins.listToAttrs (map (vlanNetdevPair "bond0") vlanIds));

      networks = let
        vlanUnit = id: "31-bond0.${builtins.toString id}";
        vlan = id: let
          hex = vlanHex.${toString id};
        in {
          matchConfig.Name = vlanIface "bond0" id;
          address = [
            "10.0.${toString id}.1/24"
            "${ulaPrefix}:${hex}::1/64"
          ];
          networkConfig = {
            IPv6SendRA = true;
            DHCPPrefixDelegation = true;
          };
          dhcpPrefixDelegationConfig = {
            SubnetId = ipv6SubnetMap.${toString id};
            Token = "::1";
          };
          ipv6SendRAConfig = {
            Managed = true;
            OtherInformation = true;
            DNS = "_link_local";
          };
          linkConfig.RequiredForOnline = "no";
        };
      in {
        "30-bond0-ports" = {
          matchConfig.Name = "enp1s0 enp3s0";
          networkConfig.Bond = "bond0";
        };

        "30-bond0" = {
          matchConfig.Name = "bond0";
          linkConfig.RequiredForOnline = "carrier";

          networkConfig = {
            Domains = ["~." "~psyclyx.xyz"];
            DHCP = "no";
          };

          address = ["10.0.0.11/24"];
          dns = ["127.0.0.1"];

          vlan = map (vlanIface "bond0") vlanIds;
        };

      }
      // builtins.listToAttrs (map (id: lib.nameValuePair (vlanUnit id) (vlan id)) dhcpVlans)
      // {
        "${vlanUnit transitVlan}" = {
          matchConfig.Name = vlanIface "bond0" transitVlan;
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            DHCPPrefixDelegation = true;
          };
          dhcpV4Config.UseRoutes = true;
          dhcpV6Config = {
            PrefixDelegationHint = "::/60";
            WithoutRA = "solicit";
          };
          linkConfig.RequiredForOnline = "no";
        };
      };
    };
  };
}
