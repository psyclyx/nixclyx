{ config, lib, ... }:
let
  cfg = config.psyclyx.services.openssh;
  ports = config.psyclyx.networking.ports.ssh;
in
{
  options.psyclyx = {
    services.openssh = {
      enable = lib.mkEnableOption "Enable OpenSSH.";
      agentAuth = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Respect SSH Agent authentication in PAM.";
        };
      };
    };
    networking.ports.ssh = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 22 ];
      description = "Ports for OpenSSH to listen on.";
    };
  };

  config = lib.mkIf cfg.enable {
    security = {
      pam = {
        sshAgentAuth = {
          enable = cfg.agentAuth.enable;
        };
      };
    };

    services = {
      openssh = {
        hostKeys = [
          {
            type = "ed25519";
            rounds = 32;
            path = "/etc/ssh/ssh_host_ed25519_key";
          }
        ];
        enable = true;
        inherit ports;
        settings = {
          PermitRootLogin = "yes";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
      };
    };
  };
}
