{ runCommand, python3 }:
runCommand "routeros-config-0.1.0" {
  meta.mainProgram = "routeros-config";
} ''
  mkdir -p $out/bin $out/share/routeros-config
  cp ${./schema.json} $out/share/routeros-config/schema.json
  substitute ${./routeros_config.py} $out/bin/routeros-config \
    --replace-warn "#!/usr/bin/env python3" "#!${python3}/bin/python3" \
    --replace-warn "@schema@" "$out/share/routeros-config/schema.json"
  chmod +x $out/bin/routeros-config
''
