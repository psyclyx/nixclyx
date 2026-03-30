{ runCommand, python3 }:
runCommand "sodola-config-0.1.0" {
  meta.mainProgram = "sodola-config";
} ''
  mkdir -p $out/bin
  substitute ${./sodola_config.py} $out/bin/sodola-config \
    --replace-warn "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  chmod +x $out/bin/sodola-config
''
