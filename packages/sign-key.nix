{writeShellApplication}:
writeShellApplication {
  name = "sign-key";
  runtimeInputs = [];
  text = ''
    set -euo pipefail

    die() { echo "error: $*" >&2; exit 1; }

    usage() {
      cat >&2 <<USAGE
    Usage: sign-key <type> [options] [pubkey]

    Types:
      host    sign as host certificate
      user    sign as user certificate

    Options:
    --ca PATH         CA key path (default: ~/.ssh/host_ca or ~/.ssh/user_ca)
    --principals STR  comma-separated principals (required)
    --identity STR    certificate identity string (required)
    --validity STR    validity interval (default: forever)
    --serial NUM      certificate serial number
    -o PATH           output cert path (default: stdout)

    Pubkey is read from stdin if not given as a positional arg.
    USAGE
      exit 1
    }

    [ $# -ge 1 ] || usage
    TYPE="$1"; shift

    case "$TYPE" in
      host) DEFAULT_CA="$HOME/.ssh/host_ca" ;;
      user) DEFAULT_CA="$HOME/.ssh/user_ca" ;;
      *)    die "unknown type: $TYPE" ;;
    esac

    CA="" PRINCIPALS="" IDENTITY="" VALIDITY="" SERIAL="" OUTPUT="" PUBKEY=""

    while [ $# -gt 0 ]; do
      case "$1" in
        --ca)         CA="$2"; shift 2 ;;
        --principals) PRINCIPALS="$2"; shift 2 ;;
        --identity)   IDENTITY="$2"; shift 2 ;;
        --validity)   VALIDITY="$2"; shift 2 ;;
        --serial)     SERIAL="$2"; shift 2 ;;
        -o)           OUTPUT="$2"; shift 2 ;;
        -*)           die "unknown option: $1" ;;
        *)            [ -z "$PUBKEY" ] || die "unexpected argument: $1"
                      PUBKEY="$1"; shift ;;
      esac
    done

    CA="''${CA:-$DEFAULT_CA}"
    [ -f "$CA" ] || die "CA key not found: $CA"
    [ -n "$PRINCIPALS" ] || die "--principals required"
    [ -n "$IDENTITY" ] || die "--identity required"

    workdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$workdir'" EXIT

    if [ -n "$PUBKEY" ]; then
      cp "$PUBKEY" "$workdir/key.pub"
    else
      cat > "$workdir/key.pub"
    fi

    args=(-s "$CA" -I "$IDENTITY" -n "$PRINCIPALS")
    [ "$TYPE" = "host" ] && args+=(-h)
    [ -n "$VALIDITY" ] && args+=(-V "$VALIDITY")
    [ -n "$SERIAL" ] && args+=(-z "$SERIAL")

    ssh-keygen "''${args[@]}" "$workdir/key.pub" >&2

    if [ -n "$OUTPUT" ]; then
      mv "$workdir/key-cert.pub" "$OUTPUT"
    else
      cat "$workdir/key-cert.pub"
    fi
  '';
}
