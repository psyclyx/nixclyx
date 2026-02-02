{
  psyclyx,
  writeShellApplication,
  jq,
  openssh,
}:
writeShellApplication {
  name = "pki-manage";
  runtimeInputs = [
    psyclyx.provision-host
    psyclyx.ensure-key
    psyclyx.sign-key
    jq
    openssh
  ];
  text = ''
    set -euo pipefail

    die() { echo "error: $*" >&2; exit 1; }

    usage() {
      cat >&2 <<USAGE
    Usage: pki-manage <command> [options]

    Commands:
      provision [host...]   provision named hosts (or all if none specified)
      check [host...]       check mode (no signing)
      enroll [options]      enroll local workstation (generate + sign keys)
      revoke <serial...>    add serials to revoked list
      generate-krl          write KRL files from revoked serials
      status                show current serial, host summary

    Enroll options:
      --principal NAME      user certificate principal (default: current user)
      --identity STR        certificate identity (default: user@hostname)
      --host                also enroll local host key (/etc/ssh/ssh_host_ed25519_key)

    Global options:
      --config PATH   config file (default: pki/config.json)
      --state PATH    state file (default: pki/state.json)
    USAGE
      exit 1
    }

    CONFIG="pki/config.json"
    STATE="pki/state.json"

    while [ $# -gt 0 ]; do
      case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --state)  STATE="$2"; shift 2 ;;
        --help)   usage ;;
        -*)       die "unknown global option: $1" ;;
        *)        break ;;
      esac
    done

    [ $# -ge 1 ] || usage
    COMMAND="$1"; shift

    [ -f "$CONFIG" ] || die "config not found: $CONFIG"

    ensure_state() {
      if [ ! -f "$STATE" ]; then
        echo '{"serial":0,"hosts":{},"certs":{},"revoked_serials":[]}' > "$STATE"
      fi
    }

    read_state() {
      jq '.' "$STATE"
    }

    write_state() {
      local tmp
      tmp=$(mktemp)
      cat > "$tmp"
      mv "$tmp" "$STATE"
    }

    get_serial() {
      jq -r '.serial' "$STATE"
    }

    get_hosts() {
      if [ $# -gt 0 ]; then
        printf '%s\n' "$@"
      else
        jq -r '.hosts | keys[]' "$CONFIG"
      fi
    }

    host_fqdn() {
      jq -r --arg h "$1" '.hosts[$h].fqdn // empty' "$CONFIG"
    }

    host_connect() {
      jq -r --arg h "$1" '.hosts[$h].connect // empty' "$CONFIG"
    }

    host_root() {
      jq -r --arg h "$1" '.hosts[$h].root // empty' "$CONFIG"
    }

    host_rotate() {
      jq -r --arg h "$1" '.hosts[$h].rotate // empty' "$CONFIG"
    }

    ca_path() {
      jq -r --arg t "$1" '.ca[$t] // empty' "$CONFIG"
    }

    cmd_provision() {
      ensure_state
      local hosts
      hosts=$(get_hosts "$@")

      while IFS= read -r hostname; do
        [ -n "$hostname" ] || continue
        local fqdn connect root rotate
        fqdn=$(host_fqdn "$hostname")
        [ -n "$fqdn" ] || die "host '$hostname' not found in config"
        connect=$(host_connect "$hostname")
        root=$(host_root "$hostname")
        rotate=$(host_rotate "$hostname")

        local serial
        serial=$(get_serial)

        local args=()
        [ -n "$connect" ] && args+=(--connect "$connect")
        [ -n "$root" ] && args+=(--root "$root")
        args+=(--host-ca "$(ca_path host)")
        args+=(--initrd-ca "$(ca_path initrd)")
        args+=(--user-ca "$(ca_path user)")
        args+=(--serial-start "$serial")
        [ "$rotate" = "true" ] && args+=(--rotate)
        args+=("$hostname" "$fqdn")

        echo "==> provisioning $hostname (serial $serial)" >&2
        local result
        result=$(provision-host "''${args[@]}")

        local next_serial
        next_serial=$(echo "$result" | jq -r '.next_serial')

        local host_serial initrd_serial user_serial
        host_serial=$(echo "$result" | jq -r '.serials.ssh_host')
        initrd_serial=$(echo "$result" | jq -r '.serials.ssh_host_initrd')
        user_serial=$(echo "$result" | jq -r '.serials.ssh_user_root')

        read_state | jq \
          --arg hostname "$hostname" \
          --argjson next_serial "$next_serial" \
          --argjson result "$result" \
          --arg host_serial "$host_serial" \
          --arg initrd_serial "$initrd_serial" \
          --arg user_serial "$user_serial" \
          '
          .serial = $next_serial |
          .hosts[$hostname] = { pubkeys: $result.pubkeys } |
          .certs[$host_serial] = {
            host: $hostname,
            identity: ($result.fqdn + "-host"),
            ca: "host"
          } |
          .certs[$initrd_serial] = {
            host: $hostname,
            identity: ($result.fqdn + "-initrd"),
            ca: "initrd"
          } |
          .certs[$user_serial] = {
            host: $hostname,
            identity: ("root@" + $result.fqdn),
            ca: "user"
          }
          ' | write_state

        echo "==> $hostname done (next serial: $next_serial)" >&2
      done <<< "$hosts"
    }

    cmd_check() {
      local hosts
      hosts=$(get_hosts "$@")

      while IFS= read -r hostname; do
        [ -n "$hostname" ] || continue
        local fqdn connect root
        fqdn=$(host_fqdn "$hostname")
        [ -n "$fqdn" ] || die "host '$hostname' not found in config"
        connect=$(host_connect "$hostname")
        root=$(host_root "$hostname")

        local args=(--check)
        [ -n "$connect" ] && args+=(--connect "$connect")
        [ -n "$root" ] && args+=(--root "$root")
        args+=("$hostname" "$fqdn")

        echo "==> checking $hostname" >&2
        provision-host "''${args[@]}"
      done <<< "$hosts"
    }

    cmd_revoke() {
      [ $# -ge 1 ] || die "revoke requires at least one serial number"
      ensure_state

      local serials=("$@")
      local serial_json
      serial_json=$(printf '%s\n' "''${serials[@]}" | jq -R 'tonumber' | jq -s '.')

      read_state | jq \
        --argjson new_serials "$serial_json" \
        '.revoked_serials = (.revoked_serials + $new_serials | unique | sort)' \
        | write_state

      echo "revoked serials: ''${serials[*]}" >&2
    }

    cmd_generate_krl() {
      ensure_state

      local revoked
      revoked=$(jq -r '.revoked_serials[]' "$STATE")
      if [ -z "$revoked" ]; then
        echo "no revoked serials, nothing to do" >&2
        return 0
      fi

      local version
      version=$(get_serial)

      local config_dir
      config_dir=$(dirname "$CONFIG")

      for ca_type in host initrd user; do
        local ca_key krl_path
        ca_key=$(ca_path "$ca_type")
        ca_key="''${ca_key/#\~/$HOME}"
        krl_path="''${config_dir}/krl-''${ca_type}.krl"

        local ca_serials=""
        while IFS= read -r serial; do
          local cert_ca
          cert_ca=$(jq -r --arg s "$serial" '.certs[$s].ca // empty' "$STATE")
          if [ "$cert_ca" = "$ca_type" ]; then
            ca_serials+="serial: $serial"$'\n'
          fi
        done <<< "$revoked"

        if [ -z "$ca_serials" ]; then
          echo "no revoked serials for $ca_type CA, skipping" >&2
          continue
        fi

        local spec_file
        spec_file=$(mktemp)
        echo -n "$ca_serials" > "$spec_file"

        ssh-keygen -k -f "$krl_path" -s "$ca_key" -z "$version" "$spec_file"
        rm -f "$spec_file"

        echo "wrote $krl_path (version $version)" >&2
      done
    }

    cmd_status() {
      ensure_state

      local serial host_count cert_count revoked_count
      serial=$(get_serial)
      host_count=$(jq '.hosts | length' "$STATE")
      cert_count=$(jq '.certs | length' "$STATE")
      revoked_count=$(jq '.revoked_serials | length' "$STATE")

      echo "serial:   $serial"
      echo "hosts:    $host_count"
      echo "certs:    $cert_count"
      echo "revoked:  $revoked_count"

      if [ "$host_count" -gt 0 ]; then
        echo ""
        echo "hosts:"
        jq -r '.hosts | to_entries[] | "  \(.key)"' "$STATE"
      fi

      if [ "$revoked_count" -gt 0 ]; then
        echo ""
        echo "revoked serials:"
        jq -r '.revoked_serials[] | "  \(.)"' "$STATE"
      fi
    }

    cmd_enroll() {
      ensure_state
      local principal="" identity="" enroll_host=""

      while [ $# -gt 0 ]; do
        case "$1" in
          --principal) principal="$2"; shift 2 ;;
          --identity)  identity="$2"; shift 2 ;;
          --host)      enroll_host=1; shift ;;
          *)           die "unknown enroll option: $1" ;;
        esac
      done

      local current_user current_hostname current_fqdn
      current_user=$(whoami)
      current_hostname=$(hostname -s)
      current_fqdn=$(hostname -f)

      principal="''${principal:-$current_user}"
      identity="''${identity:-''${current_user}@''${current_fqdn}}"

      local serial
      serial=$(get_serial)

      # enroll user key
      echo "==> ensuring user key" >&2
      local user_pub
      user_pub=$(ensure-key user --std self --comment "''${current_user}@''${current_hostname}")

      echo "==> signing user key (serial $serial)" >&2
      local user_ca
      user_ca=$(ca_path user)
      local user_cert
      user_cert=$(echo "$user_pub" | sign-key user \
        --ca "$user_ca" \
        --principals "$principal" \
        --identity "$identity" \
        --serial "$serial")

      local user_cert_path="$HOME/.ssh/id_ed25519-cert.pub"
      echo "$user_cert" > "$user_cert_path"
      echo "==> wrote $user_cert_path" >&2

      local user_serial="$serial"
      serial=$((serial + 1))

      # update state with user cert
      read_state | jq \
        --argjson serial "$serial" \
        --arg name "$current_hostname" \
        --arg user_pub "$user_pub" \
        --arg user_serial "$user_serial" \
        --arg identity "$identity" \
        '
        .serial = $serial |
        .hosts[$name].pubkeys.ssh_user = $user_pub |
        .certs[($user_serial | tostring)] = {
          host: $name,
          identity: $identity,
          ca: "user"
        }
        ' | write_state

      if [ -n "$enroll_host" ]; then
        echo "==> ensuring host key" >&2
        local host_pub
        host_pub=$(ensure-key host --std sshd)

        echo "==> signing host key (serial $serial)" >&2
        local host_ca
        host_ca=$(ca_path host)
        local host_identity="''${current_fqdn}-host"
        local host_cert
        host_cert=$(echo "$host_pub" | sign-key host \
          --ca "$host_ca" \
          --principals "''${current_hostname},''${current_fqdn}" \
          --identity "$host_identity" \
          --serial "$serial")

        local host_cert_path="/etc/ssh/ssh_host_ed25519_key-cert.pub"
        echo "$host_cert" > "$host_cert_path"
        echo "==> wrote $host_cert_path" >&2

        local host_serial="$serial"
        serial=$((serial + 1))

        read_state | jq \
          --argjson serial "$serial" \
          --arg name "$current_hostname" \
          --arg host_pub "$host_pub" \
          --arg host_serial "$host_serial" \
          --arg identity "$host_identity" \
          '
          .serial = $serial |
          .hosts[$name].pubkeys.ssh_host = $host_pub |
          .certs[($host_serial | tostring)] = {
            host: $name,
            identity: $identity,
            ca: "host"
          }
          ' | write_state

        echo "==> host enrolled (next serial: $serial)" >&2
      fi

      echo "==> enroll complete (next serial: $serial)" >&2
    }

    case "$COMMAND" in
      provision)    cmd_provision "$@" ;;
      check)        cmd_check "$@" ;;
      enroll)       cmd_enroll "$@" ;;
      revoke)       cmd_revoke "$@" ;;
      generate-krl) cmd_generate_krl ;;
      status)       cmd_status ;;
      *)            die "unknown command: $COMMAND" ;;
    esac
  '';
}
