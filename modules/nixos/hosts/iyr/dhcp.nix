{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;

  labServers = lib.sort (a: b: a.n < b.n) (lib.mapAttrsToList (name: host: {
    inherit name;
    n = host.labIndex;
  }) (lib.filterAttrs (_: host: host.labIndex != null) topo.hosts));

  protectedHostnames = ["iyr"] ++ map (s: s.name) labServers;

  unboundControl = "${pkgs.unbound}/bin/unbound-control";

  keaDnsHookScript = pkgs.writeShellScript "kea-dns-hook" ''
    DOMAIN="${topo.domains.home}"
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
          local PTR_NAME
          PTR_NAME=$(${pkgs.python3}/bin/python3 -c "import ipaddress; print(ipaddress.ip_address('$address').reverse_pointer)")
          ${unboundControl} local_data "''${PTR_NAME}. 300 IN PTR ''${FQDN}." || true
          ;;
        remove)
          ${pkgs.coreutils}/bin/rm -f "$STATE_FILE"
          rebuild_forward "$HOSTNAME" "$ZONE" "$FQDN"
          local PTR_NAME
          PTR_NAME=$(${pkgs.python3}/bin/python3 -c "import ipaddress; print(ipaddress.ip_address('$address').reverse_pointer)")
          ${unboundControl} local_data_remove "''${PTR_NAME}." || true
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

  hooksLibraries = [
    {
      library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
      parameters = {
        name = "${keaDnsHookScript}";
        sync = false;
      };
    }
  ];
in {
  config = lib.mkIf (config.psyclyx.nixos.host == "iyr") {
    psyclyx.topology.dhcp = {
      enable = true;
      pools = {
        main = {
          network = "main";
          ipv4Range = { start = "10.0.10.100"; end = "10.0.10.199"; };
        };
        rack = {
          network = "rack";
          ipv4Range = { start = "10.157.10.100"; end = "10.157.10.199"; };
        };
        data = {
          network = "data";
          ipv4Range = { start = "10.0.30.100"; end = "10.0.30.199"; };
        };
        mgmt = {
          network = "mgmt";
          ipv4Range = { start = "10.0.240.100"; end = "10.0.240.199"; };
        };
      };
      extraDhcp4 = {
        hooks-libraries = hooksLibraries;
      };
      extraDhcp6 = {
        hooks-libraries = hooksLibraries;
        # Suppress per-packet INFO noise (lab BMC interfaces solicit aggressively).
        # WARN still surfaces actual errors.
        loggers = [
          {
            name = "kea-dhcp6";
            output_options = [{output = "stdout";}];
            severity = "WARN";
          }
        ];
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
