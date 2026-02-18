{
  config,
  lib,
  pkgs,
  nixclyx,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = nixclyx.lib.topology lib topo;
  conventions = topo.conventions;

  labServers = lib.sort (a: b: a.n < b.n) (lib.mapAttrsToList (name: host: {
    inherit name;
    n = host.labIndex;
    interfaces = host.mac;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  protectedHostnames = ["iyr"] ++ map (s: s.name) labServers;

  unboundControl = "${pkgs.unbound}/bin/unbound-control";

  keaDnsHookScript = pkgs.writeShellScript "kea-dns-hook" ''
    DOMAIN="${conventions.homeDomain}"
    STATE_DIR="/run/kea-dns-state"

    ${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR"

    get_zone() {
      case "$1" in
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList (id: zone: "${id}) echo \"${zone}\" ;;") dt.vlanNameMap)}
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
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
  in {
    id = vlanId;
    subnet = "${net.prefix}.0/${toString net.prefixLen}";
    pools = [{pool = "${net.pool4Start} - ${net.pool4End}";}];
    "option-data" = [
      {
        name = "routers";
        data = net.gateway4;
      }
      {
        name = "domain-name-servers";
        data = net.gateway4;
      }
      {
        name = "domain-name";
        data = net.zoneName;
      }
      {
        name = "domain-search";
        data = "${net.zoneName}, ${conventions.homeDomain}";
      }
    ];
    reservations =
      if net.labIface == null
      then []
      else
        map (s: {
          "hw-address" = s.interfaces.${net.labIface};
          "ip-address" = "${net.prefix}.${toString (conventions.hostBaseOffset + s.n)}";
          hostname = s.name;
        })
        labServers;
  };

  mkSubnet6 = vlanId: let
    name = dt.vlanNameMap.${toString vlanId};
    net = dt.networks.${name};
    prefix6 = "${topo.ipv6UlaPrefix}:${net.vlanHex}";
  in {
    id = vlanId;
    subnet = net.subnet6;
    pools = [{pool = "${net.pool6Start} - ${net.pool6End}";}];
    "option-data" = [
      {
        name = "dns-servers";
        data = net.gateway6;
      }
      {
        name = "domain-search";
        data = "${net.zoneName}, ${conventions.homeDomain}";
      }
    ];
    reservations =
      if net.labIface == null
      then []
      else
        map (s: {
          "hw-address" = s.interfaces.${net.labIface};
          "ip-addresses" = ["${prefix6}::${dt.utils.intToHex (conventions.hostBaseOffset + s.n)}"];
          hostname = s.name;
        })
        labServers;
  };
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    psyclyx.nixos.services.kea = {
      enable = true;
      interfaces = map (id: "bond0.${toString id}") dt.dhcpVlans;
      subnets = map mkSubnet dt.dhcpVlans;
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
        interfaces-config.interfaces = map (id: "bond0.${toString id}") dt.dhcpVlans;
        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp6.leases";
        };
        valid-lifetime = 3600;
        renew-timer = 900;
        rebind-timer = 1800;
        subnet6 = map mkSubnet6 dt.dhcpVlans;
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
  };
}
