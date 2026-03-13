{
  writeShellApplication,
  redfishtool,
  ilo4-console,
}:
writeShellApplication {
  name = "ilo";
  runtimeInputs = [redfishtool ilo4-console];
  text = ''
    usage() {
      cat <<EOF
    Usage: ilo <command> [args...]

    Commands:
      console                         Open the iLO4 Java KVM console
      power <on|off|reset|status>     Server power control
      info                            Show server overview
      redfish [args...]               Run redfishtool directly (no args for help)
      help                            Show this help

    Environment:
      ILO_HOST      iLO hostname or IP (required)
      ILO_USER      iLO username (required)
      ILO_PASSWORD  iLO password (required)
    EOF
    }

    require_creds() {
      local missing=()
      [ -z "''${ILO_HOST:-}" ] && missing+=(ILO_HOST)
      [ -z "''${ILO_USER:-}" ] && missing+=(ILO_USER)
      [ -z "''${ILO_PASSWORD:-}" ] && missing+=(ILO_PASSWORD)
      if [ ''${#missing[@]} -gt 0 ]; then
        echo "error: missing required environment: ''${missing[*]}" >&2
        return 1
      fi
    }

    rf() {
      redfishtool -r "$ILO_HOST" -u "$ILO_USER" -p "$ILO_PASSWORD" -S Always "$@"
    }

    cmd="''${1:-help}"; shift || true
    case "$cmd" in
      console)
        require_creds
        ilo4-console "$@"
        ;;
      power)
        require_creds
        action="''${1:-status}"; shift || true
        case "$action" in
          on)     rf Systems -F reset On ;;
          off)    rf Systems -F reset ForceOff ;;
          reset)  rf Systems -F reset ForceRestart ;;
          status) rf Systems -F get "$@" ;;
          *)      echo "Unknown power action: $action" >&2; exit 1 ;;
        esac
        ;;
      info)
        require_creds
        rf Systems -F get "$@"
        ;;
      redfish)
        if [ $# -eq 0 ]; then
          redfishtool -h
        else
          require_creds
          rf "$@"
        fi
        ;;
      help|--help|-h)
        usage
        ;;
      *)
        echo "error: unknown command '$cmd'" >&2
        echo "Run 'ilo help' for usage." >&2
        exit 1
        ;;
    esac
  '';
}
