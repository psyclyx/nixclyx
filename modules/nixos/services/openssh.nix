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
    psyclyx.nixos.network.ports.ssh = let
      topo = config.psyclyx.topology;
      hostName = config.networking.hostName;
      thisHost = topo.hosts.${hostName} or null;
    in [
      (if thisHost != null then thisHost.sshPort else 22)
    ];

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
        Ciphers = ["aes128-gcm@openssh.com" "aes256-gcm@openssh.com" "chacha20-poly1305@openssh.com"];
      };

      extraConfig = ''
        TrustedUserCAKeys /etc/ssh/ca_user.pub
        HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
      '';
    };

    environment.etc."ssh/ca_user.pub".text = nixclyx.keys.ca.user;

    # Ensure private host keys are 0600. Preservation bind-mounts may
    # restore them with wrong permissions, causing sshd to refuse startup.
    system.activationScripts.ssh-host-key-perms = lib.stringAfter ["etc"] ''
      ${lib.concatMapStringsSep "\n" (k: ''
        if [ -f "${k.path}" ]; then
          chmod 0600 "${k.path}"
        fi
      '') config.services.openssh.hostKeys}
    '';

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
