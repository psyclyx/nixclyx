{ runCommand, bash, openssh, makeWrapper }:
runCommand "commit-confirm-0.1.0" {
  nativeBuildInputs = [ makeWrapper ];
  meta.mainProgram = "commit-confirm";
} ''
  mkdir -p $out/bin
  substitute ${./commit-confirm.sh} $out/bin/commit-confirm \
    --replace-warn "#!/usr/bin/env bash" "#!${bash}/bin/bash"
  chmod +x $out/bin/commit-confirm
  # ssh from the closure; colmena is expected from the ambient dev shell
  # (it must run against the monorepo-root hive anyway).
  wrapProgram $out/bin/commit-confirm --prefix PATH : ${openssh}/bin
''
