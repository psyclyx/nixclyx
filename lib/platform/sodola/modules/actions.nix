# Sodola platform — pull / diff / deploy actions.
#
# Target-agnostic: the switch is an argument. Auth is a cookie derived
# from the configured credentials; a fresh login.cgi POST establishes the
# session (the bare cookie is rejected post-reboot).
{ config, lib, pkgs, sodolaLib, ... }:
let
  s = config.sodola;
  jsonFile = config.system.build.json;
  cookieValue = builtins.hashString "md5" "${s.auth.username}${s.password}";
  cookie = "${s.auth.username}=${cookieValue}";
  loginCmd = ''
    curl -sf --connect-timeout 5 \
      -e "http://$target/" \
      -d "username=${s.auth.username}&password=${s.password}&Response=${cookieValue}" \
      "http://$target/login.cgi" > /dev/null'';
  pullCmd = ''
    ${loginCmd} && curl -sf --connect-timeout 5 \
      -b "${cookie}" -e "http://$target/" \
      "http://$target/config_back.cgi?cmd=conf_backup"'';
in {
  system.build = {
    pull = pkgs.writeShellApplication {
      name = "sodola-pull";
      runtimeInputs = [ pkgs.curl sodolaLib.render ];
      text = ''
        target="''${1:?usage: sodola-pull <host> [--raw]}"
        if [ "''${2:-}" = "--raw" ]; then
          ${pullCmd}
        else
          ${pullCmd} | sodola-config parse
        fi
      '';
    };
    diff = pkgs.writeShellApplication {
      name = "sodola-diff";
      runtimeInputs = [ pkgs.curl sodolaLib.render pkgs.diffutils ];
      text = ''
        target="''${1:?usage: sodola-diff <host>}"
        live=$(${pullCmd} | sodola-config parse)
        desired=$(sodola-config generate < ${jsonFile} | sodola-config parse)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true
      '';
    };
    deploy = pkgs.writeShellApplication {
      name = "sodola-deploy";
      runtimeInputs = [ pkgs.curl sodolaLib.render ];
      text = ''
        target="''${1:?usage: sodola-deploy <host>}"
        echo "Generating config..." >&2
        tmpfile=$(mktemp)
        trap 'rm -f "$tmpfile"' EXIT
        sodola-config generate < ${jsonFile} > "$tmpfile"

        echo "Logging in to $target..." >&2
        ${loginCmd}

        echo "Uploading to $target..." >&2
        curl -sf --connect-timeout 5 \
          -b "${cookie}" -e "http://$target/" \
          -F "submitFile=@$tmpfile" \
          "http://$target/config_back.cgi?cmd=conf_restore" >/dev/null

        echo "Rebooting switch..." >&2
        curl -sf --connect-timeout 5 \
          -b "${cookie}" -e "http://$target/" \
          -d "cmd=reboot" \
          "http://$target/reboot.cgi" >/dev/null || true

        echo "Deploy complete. Switch unreachable for ~30s." >&2
      '';
    };
  };
}
