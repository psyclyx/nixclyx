# Sodola platform — pull / diff / deploy actions.
#
# The host is an argument; credentials come from the environment
# (`SODOLA_USER`, `SODOLA_PASSWORD`), defaulting the user to the fleet's
# declared one. The session cookie is `user=md5(user+password)`; a fresh
# login.cgi POST establishes the session before it is honoured.
{ config, lib, pkgs, sodolaLib, ... }:
let
  s = config.sodola;
  jsonFile = config.system.build.json;
  # Shared prologue: resolve creds and the derived cookie from the env.
  creds = ''
    host="$1"; shift || true
    user="''${SODOLA_USER:-${s.auth.username}}"
    : "''${SODOLA_PASSWORD:?set SODOLA_PASSWORD}"
    resp=$(printf '%s' "$user$SODOLA_PASSWORD" | md5sum | cut -d' ' -f1)
    cookie="$user=$resp"
    login() {
      curl -sf --connect-timeout 5 -e "http://$host/" \
        -d "username=$user&password=$SODOLA_PASSWORD&Response=$resp" \
        "http://$host/login.cgi" > /dev/null
    }
    fetch() {
      curl -sf --connect-timeout 5 -b "$cookie" -e "http://$host/" \
        "http://$host/config_back.cgi?cmd=conf_backup"
    }
  '';
in {
  system.build = {
    pull = pkgs.writeShellApplication {
      name = "sodola-pull";
      runtimeInputs = [ pkgs.curl pkgs.coreutils sodolaLib.render ];
      text = ''
        usage() { echo "usage: sodola-pull <host> [--raw]" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        ${creds}
        login
        if [ "''${1:-}" = "--raw" ]; then fetch; else fetch | sodola-config parse; fi
      '';
    };
    diff = pkgs.writeShellApplication {
      name = "sodola-diff";
      runtimeInputs = [ pkgs.curl pkgs.coreutils sodolaLib.render pkgs.diffutils ];
      text = ''
        usage() { echo "usage: sodola-diff <host>" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        ${creds}
        login
        live=$(fetch | sodola-config parse)
        desired=$(sodola-config generate < ${jsonFile} | sodola-config parse)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true
      '';
    };
    deploy = pkgs.writeShellApplication {
      name = "sodola-deploy";
      runtimeInputs = [ pkgs.curl pkgs.coreutils sodolaLib.render ];
      text = ''
        usage() { echo "usage: sodola-deploy <host>" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        ${creds}

        tmpfile=$(mktemp)
        trap 'rm -f "$tmpfile"' EXIT
        sodola-config generate < ${jsonFile} > "$tmpfile"

        echo "Logging in to $host ..." >&2
        login
        echo "Uploading to $host ..." >&2
        curl -sf --connect-timeout 5 -b "$cookie" -e "http://$host/" \
          -F "submitFile=@$tmpfile" \
          "http://$host/config_back.cgi?cmd=conf_restore" > /dev/null
        echo "Rebooting $host ..." >&2
        curl -sf --connect-timeout 5 -b "$cookie" -e "http://$host/" \
          -d "cmd=reboot" "http://$host/reboot.cgi" > /dev/null || true
        echo "Deploy complete. $host is unreachable for ~30s." >&2
      '';
    };
  };
}
