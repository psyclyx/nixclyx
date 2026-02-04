{
  config,
  lib,
  ...
}: let
  inherit (config.psyclyx.nixos.deps) nixclyx;
  cfg = config.psyclyx.nixos.services.openssh;
  ports = config.psyclyx.nixos.network.ports.ssh;
in {
  options = {
    psyclyx.nixos = {
      network.ports.ssh = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [22];
        description = "Ports for OpenSSH to listen on.";
      };

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

      extraConfig = ''
        TrustedUserCAKeys /etc/ssh/ca_user.pub
        HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
        AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
      '';
    };
    environment.etc = {
      "ssh/ca_user.pub".text = nixclyx.common.keys.ca.user;
      "ssh/auth_principals/psyc".text = "admin";
      "ssh/auth_principals/root".text = "admin";
    };
  };
}
