{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.roles.llm-agent;
in
{

  options = {
    psyclyx.roles.llm-agent = {
      enable = mkEnableOption "LLM AI agent clients";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.aider-chat-with-help
      pkgs.claude-code
    ];
  };
}
