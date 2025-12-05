pkgs:
pkgs.buildEnv {
  name = "env-llm";
  paths = [
    pkgs.claude-code
    pkgs.beads
  ];
  meta.description = "LLM and AI development tools";
}
