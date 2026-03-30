{ runCommand, python3 }:
runCommand "routeros-config-0.1.0" {
  meta.mainProgram = "routeros-config";
} ''
  mkdir -p $out/bin
  substitute ${./routeros_config.py} $out/bin/routeros-config \
    --replace-warn "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  chmod +x $out/bin/routeros-config
''
