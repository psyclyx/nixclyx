{
  lib,
  makeBinaryWrapper,
  symlinkJoin,
  pi-coding-agent,
  git,
  jq,
  ripgrep,
}:
let
  extensionDir = ./extensions/memory;
  extension = "${extensionDir}/index.ts";
  # Vendored copy of pi's example subagent extension, customized:
  # spawns children with --exclude-tools subagent (no recursive delegation),
  # injects the available-agents blurb into the system prompt, and adds the
  # /agents command. Imports ./agents.ts relatively, so it ships as a dir.
  subagentExtensionDir = ./extensions/subagent;
  subagentExtension = "${subagentExtensionDir}/index.ts";
in
symlinkJoin {
  name = "nixclyx-pi-${pi-coding-agent.version}";
  paths = [ pi-coding-agent ];
  nativeBuildInputs = [ makeBinaryWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/pi" \
      --set PI_PACKAGE_DIR "${pi-coding-agent}/lib/node_modules/pi-monorepo" \
      --add-flags ${lib.escapeShellArg "--extension ${extension}"} \
      --add-flags ${lib.escapeShellArg "--extension ${subagentExtension}"} \
      --prefix PATH : ${lib.makeBinPath [
        git
        jq
        ripgrep
      ]}
  '';

  passthru = {
    inherit extension subagentExtension;
    # agents/ and prompts/ are read by pi (and by the subagent extension's
    # agent discovery) from the agent dir; the home-manager module at
    # modules/home/programs/pi.nix symlinks these into ~/.pi/agent.
    agentFiles = ./agents;
    promptFiles = ./prompts;
    unwrapped = pi-coding-agent;
  };

  meta = pi-coding-agent.meta // {
    description = "Pi coding agent with nixclyx extensions";
    mainProgram = "pi";
  };
}
