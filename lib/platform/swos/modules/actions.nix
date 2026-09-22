# SwOS platform — pull / diff / deploy actions.
#
# The host is an argument; credentials come from the environment
# (`SWOS_USER`, `SWOS_PASSWORD`), defaulting the user to the fleet's
# declared one. Nothing connection-shaped is baked into the artifact.
{ config, lib, pkgs, swosLib, ... }:
let
  s = config.swos;
  jsonFile = config.system.build.json;
in {
  system.build = {
    pull = pkgs.writeShellApplication {
      name = "swos-pull";
      runtimeInputs = [ pkgs.curl swosLib.render ];
      text = ''
        usage() { echo "usage: swos-pull <host> [--raw]" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        host="$1"; shift
        user="''${SWOS_USER:-${s.username}}"
        : "''${SWOS_PASSWORD:?set SWOS_PASSWORD}"

        fetch() {
          curl -sf --connect-timeout 5 --digest -u "$user:$SWOS_PASSWORD" "http://$host/backup.swb"
        }
        if [ "''${1:-}" = "--raw" ]; then fetch; else fetch | swos-config parse; fi
      '';
    };
    diff = pkgs.writeShellApplication {
      name = "swos-diff";
      runtimeInputs = [ pkgs.curl swosLib.render pkgs.diffutils ];
      text = ''
        usage() { echo "usage: swos-diff <host>" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        host="$1"
        user="''${SWOS_USER:-${s.username}}"
        : "''${SWOS_PASSWORD:?set SWOS_PASSWORD}"

        live=$(curl -sf --connect-timeout 5 --digest -u "$user:$SWOS_PASSWORD" \
          "http://$host/backup.swb" | swos-config parse)
        desired=$(swos-config generate < ${jsonFile} | swos-config parse)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true
      '';
    };
    deploy = pkgs.writeShellApplication {
      name = "swos-deploy";
      runtimeInputs = [ pkgs.curl swosLib.render pkgs.python3 ];
      text = ''
        usage() { echo "usage: swos-deploy <host>" >&2; }
        [ $# -ge 1 ] || { usage; exit 2; }
        host="$1"
        user="''${SWOS_USER:-${s.username}}"
        : "''${SWOS_PASSWORD:?set SWOS_PASSWORD}"

        tmpfile=$(mktemp --suffix=.swb)
        trap 'rm -f "$tmpfile"' EXIT
        swos-config generate < ${jsonFile} > "$tmpfile"

        echo "Deploying to $host ..." >&2
        # SwOS ignores multipart backup uploads; POST each section.
        python3 - "$tmpfile" "$host" "$user" "$SWOS_PASSWORD" << 'DEPLOY_EOF'
import re, subprocess, sys

data = open(sys.argv[1]).read()
host, user, password = sys.argv[2], sys.argv[3], sys.argv[4]
sections = []
i = 0
while i < len(data):
    m = re.match(r'(\w+\.b):', data[i:])
    if not m:
        i += 1
        continue
    name = m.group(1)
    start = i + len(m.group(0))
    depth = 0
    for j, c in enumerate(data[start:]):
        if c in '{[': depth += 1
        elif c in '}]': depth -= 1
        if depth == 0:
            sections.append((name, data[start:start+j+1]))
            i = start + j + 2
            break
    else:
        break

failed = False
for name, content in sections:
    r = subprocess.run(
        ['curl', '-sf', '--connect-timeout', '5', '--max-time', '10',
         '--digest', '-u', f'{user}:{password}',
         '-X', 'POST', '-d', content, f'http://{host}/' + name],
        capture_output=True, timeout=15,
    )
    print(f'  {"OK" if r.returncode == 0 else "FAIL"}: {name}', file=sys.stderr)
    failed = failed or r.returncode != 0
if failed:
    sys.exit(1)
DEPLOY_EOF
        echo "Deploy complete." >&2
      '';
    };
  };
}
