# sodola — talk to a Sodola web-managed switch.
#
# Follows ssh's contract: the target is a configured name, the tool
# finds its connection the standard way. Form auth: a login POST mints
# the session, then `user=md5(user+password)` rides as a cookie.
# Credentials come from $SODOLA_USER/$SODOLA_PASSWORD, then ~/.netrc.
{ writeShellApplication, curl, gawk, coreutils, sodola-config, lib }:
let
  creds = (import ../../lib/credentials.nix { inherit lib; }).resolve "SODOLA";
in
writeShellApplication {
  name = "sodola";
  runtimeInputs = [ curl gawk coreutils sodola-config ];
  text = ''
    usage() {
      cat >&2 <<'EOF'
    usage: sodola <target> <command> [args]

      pull [--raw]   switch config as JSON (--raw for the binary)
      push           read a JSON config on stdin, restore it, reboot

    <target> is a host on your network. Credentials come from
    SODOLA_USER/SODOLA_PASSWORD or ~/.netrc, as with curl.
    EOF
    }

    [ $# -ge 2 ] || { usage; exit 2; }
    target="$1"; command="$2"; shift 2

    ${creds}
    resolve_creds "$target"
    url="http://$target"
    resp=$(printf '%s' "$user$password" | md5sum | cut -d' ' -f1)
    cookie="$user=$resp"

    login() {
      curl -sf --connect-timeout 5 -e "$url/" \
        -d "username=$user&password=$password&Response=$resp" \
        "$url/login.cgi" > /dev/null
    }
    fetch() {
      curl -sf --connect-timeout 5 -b "$cookie" -e "$url/" \
        "$url/config_back.cgi?cmd=conf_backup"
    }

    case "$command" in
      pull)
        login
        if [ "''${1:-}" = "--raw" ]; then fetch; else fetch | sodola-config parse; fi
        ;;
      push)
        bin=$(mktemp)
        trap 'rm -f "$bin"' EXIT
        sodola-config generate > "$bin"
        login
        curl -sf --connect-timeout 5 -b "$cookie" -e "$url/" \
          -F "submitFile=@$bin" "$url/config_back.cgi?cmd=conf_restore" > /dev/null
        curl -sf --connect-timeout 5 -b "$cookie" -e "$url/" \
          -d "cmd=reboot" "$url/reboot.cgi" > /dev/null || true
        echo "sodola: $target reboots; unreachable for ~30s." >&2
        ;;
      *)
        usage; exit 2
        ;;
    esac
  '';
}
