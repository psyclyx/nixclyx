{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.openssh;
  ports = config.psyclyx.network.ports.ssh;
in
{
  options = {
    psyclyx = {
      network.ports.ssh = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 22 ];
        description = "Ports for OpenSSH to listen on.";
      };

      nixos.services.openssh = {
        enable = lib.mkEnableOption "Enable OpenSSH.";
        agentAuth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Respect SSH Agent authentication in PAM.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.sshAgentAuth.enable = lib.mkIf cfg.agentAuth.enable cfg.agentAuth.enable;
    services.openssh = {
      enable = true;
      inherit ports;
      hostKeys = [
        {
          type = "ed25519";
          rounds = 32;
          path = "/etc/ssh/ssh_host_ed25519_key";
        }
      ];

      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
