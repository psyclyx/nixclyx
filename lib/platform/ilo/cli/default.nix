# ilo — talk to an HPE iLO over Redfish.
#
# Follows ssh's contract: the target is a configured name and the tool
# finds its connection the standard way. This is Redfish (+ the KVM
# console); plain ssh to a BMC is just a host entry, like anything else.
# Credentials come from $ILO_USER/$ILO_PASSWORD, then ~/.netrc.
{ writeShellApplication, curl, redfishtool, ilo4-console, ilo-config, gawk, coreutils, lib }:
let
  creds = (import ../../lib/credentials.nix { inherit lib; }).resolve "ILO";
in
writeShellApplication {
  name = "ilo";
  runtimeInputs = [ curl redfishtool ilo4-console gawk coreutils ilo-config ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: ilo <target> <command> [args]

      info              system overview
      power [action]    on | off | reset | status (default: status)
      apply              read a desired-state JSON on stdin and apply it
      plan               read a desired-state JSON on stdin and diff it
      console            open the KVM console

    <target> is a BMC address or name. Credentials come from
    ILO_USER/ILO_PASSWORD or ~/.netrc, as with curl.
    EOF
    }

    [ $# -ge 2 ] || { usage; exit 2; }
    target="$1"; command="$2"; shift 2

    ${creds}
    resolve_creds "$target"
    rf() { redfishtool -r "$target" -u "$user" -p "$password" -S Always "$@"; }

    case "$command" in
      info)
        rf Systems -F get
        ;;
      power)
        case "''${1:-status}" in
          on)     rf Systems -F reset On ;;
          off)    rf Systems -F reset ForceOff ;;
          reset)  rf Systems -F reset ForceRestart ;;
          status) rf Systems -F get ;;
          *)      echo "unknown power action: ''${1}" >&2; exit 2 ;;
        esac
        ;;
      apply)
        ILO_USER="$user" ILO_PASSWORD="$password" ilo-config apply "$target"
        ;;
      plan)
        ILO_USER="$user" ILO_PASSWORD="$password" ilo-config apply --dry-run "$target"
        ;;
      console)
        ILO_HOST="$target" ILO_USER="$user" ILO_PASSWORD="$password" exec ilo4-console
        ;;
      *)
        usage; exit 2
        ;;
    esac
  '';
}
