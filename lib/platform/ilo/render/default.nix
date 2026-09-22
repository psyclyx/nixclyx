{ runCommand, python3 }:
runCommand "ilo-config-0.1.0" {
  meta.mainProgram = "ilo-config";
} ''
  mkdir -p $out/bin
  substitute ${./ilo_config.py} $out/bin/ilo-config \
    --replace-warn "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  chmod +x $out/bin/ilo-config
''
