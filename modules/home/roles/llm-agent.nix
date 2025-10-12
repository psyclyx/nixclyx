{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfgEnabled = config.psyclyx.roles.llm-agent;
in
{

  options = {
    psyclyx.roles.llm-agent = mkEnableOption "llm clients";
  };

  config = mkIf cfgEnabled {
    home.packages = [
      pkgs.aider-chat-with-help
      pkgs.claude-code
    ];
  };
}
