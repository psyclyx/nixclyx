{
  path = ["psyclyx" "home" "programs" "pi-coding-agent"];
  description = "Pi coding agent CLI";
  config = {pkgs, ...}: {
    home.packages = [pkgs.llm-agents.pi];
  };
}
