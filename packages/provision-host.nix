{
  psyclyx,
  writeShellApplication,
  jq,
}:
writeShellApplication {
  name = "provision-host";
  runtimeInputs = [psyclyx.ensure-key psyclyx.sign-key jq];
  text = ''
    set -euo pipefail

    die() { echo "error: $*" >&2; exit 1; }

    usage() {
      cat >&2 <<USAGE
    Usage: provision-host [options] <hostname> <fqdn>

    Options:
      --connect HOST    ssh destination override
      --root PATH       remote path prefix (default: none)
      --host-ca PATH    host CA key (default: ~/.ssh/host_ca)
      --user-ca PATH    user CA key (default: ~/.ssh/user_ca)
      --initrd-ca PATH  initrd host CA key (default: ~/.ssh/initrd_host_ca)
      --rotate          rotate all keys before generating
      --check           check only, don't generate or sign
    USAGE
      exit 1
    }

    CONNECT="" ROOT="" HOST_CA="" INITRD_CA="" USER_CA="" ROTATE="" CHECK=""

    while [ $# -gt 0 ]; do
      case "$1" in
        --connect)    CONNECT="$2"; shift 2 ;;
        --root)       ROOT="$2"; shift 2 ;;
        --host-ca)    HOST_CA="$2"; shift 2 ;;
        --initrd-ca)  INITRD_CA="$2"; shift 2 ;;
        --user-ca)    USER_CA="$2"; shift 2 ;;
        --rotate)     ROTATE=1; shift ;;
        --check)      CHECK=1; shift ;;
        --help)       usage ;;
        -*)           die "unknown option: $1" ;;
        *)            break ;;
      esac
    done

    [ $# -eq 2 ] || usage
    HOSTNAME="$1" FQDN="$2"
    DEST="''${CONNECT:-root@''${FQDN}}"

    ENSURE_KEY_PATH=$(command -v ensure-key)
    ENSURE_KEY_STORE_PATH=$(dirname "$(dirname "$ENSURE_KEY_PATH")")

    if [ -z "$CHECK" ]; then
      echo "copying ensure-key to $DEST" >&2
      nix-copy-closure --to "$DEST" "$ENSURE_KEY_STORE_PATH"
    fi

    remote_ensure_key() {
      local args=("$@")
      [ -n "$ROOT" ] && args+=(--root "$ROOT")
      if [ -n "$CHECK" ]; then
        args+=(--check)
      elif [ -n "$ROTATE" ]; then
        args+=(--rotate)
      fi
      # shellcheck disable=SC2029
      ssh "$DEST" "$ENSURE_KEY_PATH" "''${args[@]}"
    }

    push_cert() {
      local cert="$1" remote_path="$2"
      # shellcheck disable=SC2029
      echo "$cert" | ssh "$DEST" "cat > ''${ROOT}''${remote_path}"
    }

    if [ -n "$CHECK" ]; then
      echo "checking keys on $DEST" >&2
    else
      echo "generating keys on $DEST" >&2
    fi

    host_pub=$(remote_ensure_key host --std sshd) || true
    initrd_pub=$(remote_ensure_key host --std initrd) || true
    root_pub=$(remote_ensure_key user --std root --comment "root@''${HOSTNAME}") || true
    wg_pub=$(remote_ensure_key wg --std wg) || true

    if [ -z "$CHECK" ]; then
      echo "signing keys" >&2

      sign_host_args=(host --principals "''${HOSTNAME},''${FQDN}" --identity "''${FQDN}-host")
      sign_initrd_args=(host --principals "''${HOSTNAME},''${FQDN}" --identity "''${FQDN}-initrd")
      sign_user_args=(user --principals root --identity "root@''${FQDN}")
      [ -n "$HOST_CA" ] && sign_host_args+=(--ca "$HOST_CA")
      [ -n "$INITRD_CA" ] && sign_initrd_args+=(--ca "$INITRD_CA")
      [ -n "$USER_CA" ] && sign_user_args+=(--ca "$USER_CA")

      host_cert=$(echo "$host_pub" | sign-key "''${sign_host_args[@]}")
      initrd_cert=$(echo "$initrd_pub" | sign-key "''${sign_initrd_args[@]}")
      root_cert=$(echo "$root_pub" | sign-key "''${sign_user_args[@]}")

      echo "deploying certs to $DEST" >&2

      push_cert "$host_cert" /etc/ssh/ssh_host_ed25519_key-cert.pub
      push_cert "$initrd_cert" /etc/secrets/initrd/ssh_host_ed25519_key-cert.pub
      push_cert "$root_cert" /root/.ssh/id_ed25519-cert.pub
    fi

    echo "done" >&2
    jq -n \
      --arg hostname "$HOSTNAME" \
      --arg fqdn "$FQDN" \
      --arg ssh_host "$host_pub" \
      --arg ssh_host_initrd "$initrd_pub" \
      --arg ssh_user_root "$root_pub" \
      --arg wireguard "$wg_pub" \
      '{
        hostname: $hostname,
        fqdn: $fqdn,
        pubkeys: {
          ssh_host: $ssh_host,
          ssh_host_initrd: $ssh_host_initrd,
          ssh_user_root: $ssh_user_root,
          wireguard: $wireguard
        }
      }'
  '';
}
