pkgs:
pkgs.buildEnv {
  name = "env-llm";
  paths = [
    # LLM tools
    pkgs.claude-code
  ];
  meta.description = "LLM and AI development tools";
}
