# SwOS platform — pull / diff / deploy actions.
#
# Target-agnostic: the switch is an argument. The generated `.swb` is the
# build; these are the placement.
{ config, lib, pkgs, swosLib, ... }:
let
  s = config.swos;
  jsonFile = config.system.build.json;
  auth = ''--digest -u "${s.username}:${s.password}"'';
  pullCmd = ''curl -sf --connect-timeout 5 ${auth} "http://$target/backup.swb"'';
in {
  system.build = {
    pull = pkgs.writeShellApplication {
      name = "swos-pull";
      runtimeInputs = [ pkgs.curl swosLib.render ];
      text = ''
        target="''${1:?usage: swos-pull <host> [--raw]}"
        if [ "''${2:-}" = "--raw" ]; then
          ${pullCmd}
        else
          ${pullCmd} | swos-config parse
        fi
      '';
    };
    diff = pkgs.writeShellApplication {
      name = "swos-diff";
      runtimeInputs = [ pkgs.curl swosLib.render pkgs.diffutils ];
      text = ''
        target="''${1:?usage: swos-diff <host>}"
        live=$(${pullCmd} | swos-config parse)
        desired=$(swos-config generate < ${jsonFile} | swos-config parse)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true
      '';
    };
    deploy = pkgs.writeShellApplication {
      name = "swos-deploy";
      runtimeInputs = [ pkgs.curl swosLib.render pkgs.python3 ];
      text = ''
        target="''${1:?usage: swos-deploy <host>}"
        echo "Generating config..." >&2
        tmpfile=$(mktemp --suffix=.swb)
        trap 'rm -f "$tmpfile"' EXIT
        swos-config generate < ${jsonFile} > "$tmpfile"

        echo "Deploying to $target..." >&2
        # SwOS ignores multipart backup uploads; POST each section.
        python3 - "$tmpfile" "$target" << 'DEPLOY_EOF'
import re, subprocess, sys

data = open(sys.argv[1]).read()
mgmt_ip = sys.argv[2]
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
         '--digest', '-u', '${s.username}:${s.password}',
         '-X', 'POST', '-d', content,
         f'http://{mgmt_ip}/' + name],
        capture_output=True, timeout=15
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
