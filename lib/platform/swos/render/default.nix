{ runCommand, python3 }:
runCommand "swos-config-0.1.0" {
  meta.mainProgram = "swos-config";
} ''
  mkdir -p $out/bin
  substitute ${./swos_config.py} $out/bin/swos-config \
    --replace-warn "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  chmod +x $out/bin/swos-config
''
