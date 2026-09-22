# swos — talk to a MikroTik SwOS switch.
#
# Follows ssh's contract: the target is a configured name, the tool
# finds its connection the standard way and gets out of the way. Auth is
# HTTP digest; credentials come from $SWOS_USER/$SWOS_PASSWORD, then
# ~/.netrc (`machine <target> login <user> password <pass>`).
{ writeShellApplication, curl, python3, gawk, coreutils, swos-config, lib }:
let
  creds = (import ../../lib/credentials.nix { inherit lib; }).resolve "SWOS";
in
writeShellApplication {
  name = "swos";
  runtimeInputs = [ curl python3 gawk coreutils swos-config ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: swos <target> <command> [args]

      pull [--raw]   switch config as JSON (--raw for the .swb bytes)
      push           read a JSON config on stdin and apply it
      diff           diff the switch against a JSON config on stdin

    <target> is a host on your network. Credentials come from
    SWOS_USER/SWOS_PASSWORD or ~/.netrc, as with curl.
    EOF
    }

    [ $# -ge 2 ] || { usage; exit 2; }
    target="$1"; command="$2"; shift 2

    ${creds}
    resolve_creds "$target"
    url="http://$target"

    fetch() { curl -sf --connect-timeout 5 --digest -u "$user:$password" "$url/backup.swb"; }

    case "$command" in
      pull)
        if [ "''${1:-}" = "--raw" ]; then fetch; else fetch | swos-config parse; fi
        ;;
      push)
        swb=$(mktemp --suffix=.swb)
        trap 'rm -f "$swb"' EXIT
        swos-config generate > "$swb"
        python3 ${./push.py} "$swb" "$target" "$user" "$password"
        ;;
      diff)
        swb=$(mktemp --suffix=.swb)
        trap 'rm -f "$swb"' EXIT
        swos-config generate > "$swb"
        diff -u <(fetch | swos-config parse) <(swos-config parse < "$swb") || true
        ;;
      *)
        usage; exit 2
        ;;
    esac
  '';
}
