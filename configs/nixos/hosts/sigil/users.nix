{ pkgs, inputs, ... }:
{
  nix.settings.trusted-users = [ "psyc" ];
  users = {
    users = {
      psyc = {
        isNormalUser = true;
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "video"
          "builders"
          "docker"
        ];
        openssh.authorizedKeys.keys = inputs.self.common.keys.psyc.openssh;
      };
    };
  };

  home-manager.users.psyc = {
    imports = [ ../../../home/psyc.nix ];
    psyclyx.roles.llm-agent.enable = true;
    psyclyx.configs.psyc = {
      enable = true;
      secrets = true;
    };
  };
}
