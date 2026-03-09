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
    authPrincipals = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      description = ''
        Per-user list of authorized principals for SSH certificate auth.
        Written directly to /etc/ssh/auth_principals/<user> to avoid
        nix store symlinks (OpenSSH StrictModes rejects those).
      '';
    };
  };
  config = {
    cfg,
    config,
    lib,
    nixclyx,
    ...
  }: {
    psyclyx.nixos.network.ports.ssh = lib.mkDefault [22];

    security.pam.sshAgentAuth.enable = lib.mkIf cfg.agentAuth.enable cfg.agentAuth.enable;

    psyclyx.nixos.services.openssh.authPrincipals = {
      root = ["admin"];
      psyc = ["admin"];
    };

    services.openssh = {
      enable = true;
      ports = config.psyclyx.nixos.network.ports.ssh.tcp;
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
        AuthorizedPrincipalsFile = "/etc/ssh/auth_principals/%u";
      };

      extraConfig = ''
        TrustedUserCAKeys /etc/ssh/ca_user.pub
        HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
      '';
    };

    environment.etc."ssh/ca_user.pub".text = nixclyx.keys.ca.user;

    # Write auth_principals as real files (not nix store symlinks)
    # because OpenSSH StrictModes rejects paths through /nix/store.
    system.activationScripts.ssh-auth-principals = lib.stringAfter ["etc"] ''
      mkdir -p /etc/ssh/auth_principals
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (user: principals: ''
        cat > /etc/ssh/auth_principals/${user} << 'PRINCIPALS'
      ${lib.concatStringsSep "\n" principals}
      PRINCIPALS
        chmod 644 /etc/ssh/auth_principals/${user}
      '') cfg.authPrincipals)}
    '';
  };
}
