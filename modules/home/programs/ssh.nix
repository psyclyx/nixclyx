{
  path = ["psyclyx" "home" "programs" "ssh"];
  description = "SSH configuration";
  options = {lib, ...}: {
    agentKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Private key paths loaded into ssh-agent at login (Linux only), each
        with its `-cert.pub` if present (e.g. sops secret paths). Missing
        files and keys that need a passphrase are skipped.

        AddKeysToAgent only adds a key once ssh itself reads it, so without
        this the agent starts empty every boot and agent forwarding offers
        nothing until the first direct connection. Every key in the agent is
        offered to every server, and sshd cuts the connection after
        MaxAuthTries (default 6), so list only the keys worth that.
      '';
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  in {
    programs = {
      ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*" =
          {
            AddKeysToAgent = "yes";
            Compression = false;
            UpdateHostKeys = "no";
            Ciphers = "aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com";
          }
          // lib.optionalAttrs isDarwin {UseKeychain = "yes";};
      };
    };

    services = lib.mkIf isLinux {
      ssh-agent = {
        enable = true;
      };
    };

    # agentKeys are typically sops-nix secrets, so this waits for
    # sops-nix to decrypt them.
    systemd.user.services.ssh-agent-load = lib.mkIf (isLinux && cfg.agentKeys != []) {
      Unit = {
        Description = "Load SSH keys into ssh-agent";
        Requires = ["ssh-agent.service"];
        After = ["ssh-agent.service" "sops-nix.service"];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = "SSH_AUTH_SOCK=%t/${config.services.ssh-agent.socket}";
        ExecStart = toString (pkgs.writeShellScript "ssh-agent-load" ''
          for f in ${lib.escapeShellArgs cfg.agentKeys}; do
            [ -r "$f" ] || continue
            # Passphrase-protected keys are left for AddKeysToAgent.
            ${pkgs.openssh}/bin/ssh-keygen -y -P "" -f "$f" >/dev/null 2>&1 || continue
            ${pkgs.openssh}/bin/ssh-add "$f" </dev/null
          done
        '');
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
