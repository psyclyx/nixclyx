{
  writeShellApplication,
  wireguard-tools,
}:
writeShellApplication {
  name = "ensure-key";
  runtimeInputs = [wireguard-tools];
  text = ''
    set -euo pipefail

    die() { echo "error: $*" >&2; exit 1; }

    usage() {
      cat >&2 <<USAGE
    Usage: ensure-key <type> [options]

    Types:
      host    ssh host key (outputs pubkey)
      user    ssh user key (outputs pubkey)
      wg      wireguard key (outputs pubkey)
      ca      ssh CA key (outputs pubkey)

    Common options:
      --std NAME    use standard path (see below)
      --path PATH   explicit key path
      --root PATH   prefix for --std paths (e.g. /mnt)
      --check       check only, don't generate (exit 1 if missing)
      --rotate      delete and regenerate

    Standard paths:
      host --std sshd      /etc/ssh/ssh_host_ed25519_key
      host --std initrd    /etc/secrets/initrd/ssh_host_ed25519_key
      user --std root      /root/.ssh/id_ed25519
      wg   --std wg        /etc/secrets/wireguard/private.key
      ca   --std host      ~/.ssh/host_ca
      ca   --std initrd    ~/.ssh/initrd_host_ca
      ca   --std user      ~/.ssh/user_ca

    Host options:
      --hostname NAME   short hostname for cert (default: \$(hostname))
      --fqdn NAME       fqdn for cert (default: \$(hostname -f))

    User options:
      --comment STRING  key comment (default: type-dependent)

    CA options:
      --comment STRING  key comment (default: type-dependent)
    USAGE
      exit 1
    }

    resolve_path() {
      local type="$1" std="$2" explicit="$3" root="$4"
      if [ -n "$explicit" ]; then
        echo "$explicit"
        return
      fi
      [ -n "$std" ] || die "one of --std or --path is required"
      local base
      case "''${type}:''${std}" in
        host:sshd)   base="/etc/ssh/ssh_host_ed25519_key" ;;
        host:initrd) base="/etc/secrets/initrd/ssh_host_ed25519_key" ;;
        user:root)   base="/root/.ssh/id_ed25519" ;;
        wg:wg)       base="/etc/secrets/wireguard/private.key" ;;
        ca:host)     base="$HOME/.ssh/host_ca" ;;
        ca:initrd)   base="$HOME/.ssh/initrd_host_ca" ;;
        ca:user)     base="$HOME/.ssh/user_ca" ;;
        *)           die "unknown --std '$std' for type '$type'" ;;
      esac
      echo "''${root}''${base}"
    }

    cmd_ca() {
      local std="" path="" root="" comment="" check="" rotate=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --std)     std="$2"; shift 2 ;;
          --path)    path="$2"; shift 2 ;;
          --root)    root="$2"; shift 2 ;;
          --comment) comment="$2"; shift 2 ;;
          --check)   check=1; shift ;;
          --rotate)  rotate=1; shift ;;
          *)         die "unknown option: $1" ;;
        esac
      done

      local keypath
      keypath=$(resolve_path ca "$std" "$path" "$root")

      if [ -n "$check" ]; then
        [ -f "$keypath" ] && cat "''${keypath}.pub" && exit 0
        exit 1
      fi

      if [ -n "$rotate" ]; then
        rm -f "$keypath" "''${keypath}.pub"
      fi

      if [ -f "$keypath" ]; then
        cat "''${keypath}.pub"
        exit 0
      fi

      local comment_args=()
      [ -n "$comment" ] && comment_args=(-C "$comment")
      mkdir -p "$(dirname "$keypath")"
      ensure_ssh "$keypath" "''${comment_args[@]}"
    }

    ensure_ssh() {
      local keypath="$1"; shift
      mkdir -p "$(dirname "$keypath")"
      ssh-keygen -t ed25519 "$@" -f "$keypath" -N "" >&2
      cat "''${keypath}.pub"
    }

    ensure_wg() {
      local keypath="$1"
      mkdir -p "$(dirname "$keypath")"
      if ! command -v wg >/dev/null 2>&1; then
        nix-shell -p wireguard-tools --run "umask 077; wg genkey > '$keypath' && wg pubkey < '$keypath' > '$keypath.pub'" >&2
      else
        umask 077
        wg genkey > "$keypath"
        wg pubkey < "$keypath" > "''${keypath}.pub"
      fi
      cat "''${keypath}.pub"
    }

    cmd_host() {
      local std="" path="" root="" check="" rotate=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --std)      std="$2"; shift 2 ;;
          --path)     path="$2"; shift 2 ;;
          --root)     root="$2"; shift 2 ;;
          --check)    check=1; shift ;;
          --rotate)   rotate=1; shift ;;
          *)          die "unknown option: $1" ;;
        esac
      done

      local keypath
      keypath=$(resolve_path host "$std" "$path" "$root")

      if [ -n "$check" ]; then
        [ -f "$keypath" ] && cat "''${keypath}.pub" && exit 0
        exit 1
      fi

      if [ -n "$rotate" ]; then
        rm -f "$keypath" "''${keypath}.pub" "''${keypath}-cert.pub"
      fi

      if [ -f "$keypath" ]; then
        awk '{print $1, $2}' "''${keypath}.pub"
        exit 0
      fi

      ensure_ssh "$keypath" -C "" | awk '{print $1, $2}'
    }

    cmd_user() {
      local std="" path="" root="" comment="" check="" rotate=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --std)     std="$2"; shift 2 ;;
          --path)    path="$2"; shift 2 ;;
          --root)    root="$2"; shift 2 ;;
          --comment) comment="$2"; shift 2 ;;
          --check)   check=1; shift ;;
          --rotate)  rotate=1; shift ;;
          *)         die "unknown option: $1" ;;
        esac
      done

      local keypath
      keypath=$(resolve_path user "$std" "$path" "$root")

      if [ -n "$check" ]; then
        [ -f "$keypath" ] && cat "''${keypath}.pub" && exit 0
        exit 1
      fi

      if [ -n "$rotate" ]; then
        rm -f "$keypath" "''${keypath}.pub" "''${keypath}-cert.pub"
      fi

      if [ -f "$keypath" ]; then
        cat "''${keypath}.pub"
        exit 0
      fi

      local comment_args=()
      [ -n "$comment" ] && comment_args=(-C "$comment")
      mkdir -p "$(dirname "$keypath")"
      chmod 700 "$(dirname "$keypath")"
      ensure_ssh "$keypath" "''${comment_args[@]}"
    }

    cmd_wg() {
      local std="" path="" root="" check="" rotate=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --std)    std="$2"; shift 2 ;;
          --path)   path="$2"; shift 2 ;;
          --root)   root="$2"; shift 2 ;;
          --check)  check=1; shift ;;
          --rotate) rotate=1; shift ;;
          *)        die "unknown option: $1" ;;
        esac
      done

      local keypath
      keypath=$(resolve_path wg "$std" "$path" "$root")

      if [ -n "$check" ]; then
        [ -f "$keypath" ] && cat "''${keypath}.pub" && exit 0
        exit 1
      fi

      if [ -n "$rotate" ]; then
        rm -f "$keypath" "''${keypath}.pub"
      fi

      if [ -f "$keypath" ]; then
        cat "''${keypath}.pub"
        exit 0
      fi

      ensure_wg "$keypath"
    }

    [ $# -ge 1 ] || usage
    TYPE="$1"; shift

    case "$TYPE" in
      host) cmd_host "$@" ;;
      user) cmd_user "$@" ;;
      wg)   cmd_wg "$@" ;;
      ca)   cmd_ca "$@" ;;
      *)    die "unknown type: $TYPE" ;;
    esac
  '';
}
