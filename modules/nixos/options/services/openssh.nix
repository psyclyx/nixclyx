{
  path = ["psyclyx" "nixos" "services" "openssh"];
  description = "Enable OpenSSH.";
  options = {lib, ...}: {
    agentAuth = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Respect SSH Agent authentication in PAM.";
      };
    };
  };
  extraOptions = {lib, ...}: {
    psyclyx.nixos.network.ports.ssh = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [22];
      description = "Ports for OpenSSH to listen on.";
    };
  };
  config = {
    cfg,
    config,
    lib,
    nixclyx,
    ...
  }: {
    security.pam.sshAgentAuth.enable = lib.mkIf cfg.agentAuth.enable cfg.agentAuth.enable;
    services.openssh = {
      enable = true;
      ports = config.psyclyx.nixos.network.ports.ssh;
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
      "ssh/ca_user.pub".text = nixclyx.keys.ca.user;
      "ssh/auth_principals/psyc".text = "admin";
      "ssh/auth_principals/root".text = "admin";
    };
  };
}
