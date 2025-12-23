{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.psyclyx.nixos.services.openssh;
  ports = config.psyclyx.network.ports.ssh;
in
{
  options = {
    psyclyx = {
      network.ports.ssh = mkOption {
        type = types.listOf types.port;
        default = [ 22 ];
        description = "Ports for OpenSSH to listen on.";
      };

      nixos.services.openssh = {
        enable = mkEnableOption "Enable OpenSSH.";
        agentAuth = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Respect SSH Agent authentication in PAM.";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    security.pam.sshAgentAuth.enable = mkIf cfg.agentAuth.enable cfg.agentAuth.enable;
    services.openssh = {
      enable = true;
      hostKeys = [
        {
          type = "ed25519";
          rounds = 32;
          path = "/etc/ssh/ssh_host_ed25519_key";
        }
      ];

      inherit ports;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
