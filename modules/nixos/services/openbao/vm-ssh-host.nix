# OpenBao-signed SSH host cert for microvm guests.
#
# On each boot:
#   - generate a fresh /etc/ssh/ssh_host_ed25519_key (no persistence);
#   - POST the pubkey to <mount>/sign/<role> with the host's natural
#     lab FQDN as the cert_type=host, valid_principals=<fqdn>;
#   - write the response cert to /etc/ssh/ssh_host_ed25519_key-cert.pub
#     and tell sshd to present it via HostCertificate.
#
# Operators trust the SSH host CA via `@cert-authority` in known_hosts,
# so VMs are reachable without per-host TOFU and the host key can
# rotate every boot harmlessly.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-vm-ssh-host"
  ];
  description = "OpenBao-signed SSH host cert lifecycle";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "OpenBao SSH host cert signing for this guest";

      vaultAddr = lib.mkOption {
        type = lib.types.str;
        description = "OpenBao API endpoint reachable from the guest.";
        example = "https://10.0.25.1:8200";
      };

      insecureSkipVerify = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Skip TLS verification of the OpenBao server cert.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/openbao-auth/services-token";
        description = ''
          OpenBao token used to authorize the sign request. Default
          matches the cert-auth token produced by openbao-vm-auth.
        '';
      };

      signPath = lib.mkOption {
        type = lib.types.str;
        description = "OpenBao path to POST the pubkey to, e.g. ssh-host/sign/host-cert.";
        example = "ssh-host/sign/host-cert";
      };

      hostFqdn = lib.mkOption {
        type = lib.types.str;
        description = "Hostname put into the signed cert's valid_principals.";
        example = "ab-api.lab.apt.psyclyx.net";
      };

      hostKeyPath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/ssh/ssh_host_ed25519_key";
        description = "Path to the ed25519 host key. Regenerated each boot.";
      };

      certPath = lib.mkOption {
        type = lib.types.str;
        default = "/etc/ssh/ssh_host_ed25519_key-cert.pub";
        description = "Path to write the signed host cert to.";
      };

      ttl = lib.mkOption {
        type = lib.types.str;
        default = "168h";
        description = "Requested cert TTL (role's max_ttl bounds this).";
      };
    };

  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf cfg.enable {
      systemd.services.openbao-vm-ssh-host = {
        description = "Sign SSH host key via OpenBao (${cfg.hostFqdn})";
        after = [ "openbao-vm-auth.service" ];
        wants = [ "openbao-vm-auth.service" ];
        # Run before sshd so the cert is in place when sshd starts.
        before = [ "sshd.service" ];
        wantedBy = [ "multi-user.target" "sshd.service" ];

        environment = {
          BAO_ADDR = cfg.vaultAddr;
          HOME = "/run/openbao-auth";
        } // lib.optionalAttrs cfg.insecureSkipVerify {
          VAULT_SKIP_VERIFY = "true";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "60s";
        };

        path = [
          pkgs.openbao
          pkgs.jq
          pkgs.openssh
          pkgs.bash
          pkgs.coreutils
        ];

        script = ''
          set -euo pipefail
          umask 077

          # Fresh host key each boot — no need to persist it; the cert
          # is the durable proof of identity (signed by the SSH CA).
          rm -f ${lib.escapeShellArg cfg.hostKeyPath} \
                ${lib.escapeShellArg cfg.hostKeyPath}.pub \
                ${lib.escapeShellArg cfg.certPath}
          ssh-keygen -q -t ed25519 -N "" -f ${lib.escapeShellArg cfg.hostKeyPath}

          PUBKEY=$(cat ${lib.escapeShellArg cfg.hostKeyPath}.pub)
          BAO_TOKEN="$(cat ${lib.escapeShellArg cfg.tokenFile})"
          export BAO_TOKEN

          RESP=$(bao write -format=json \
            ${lib.escapeShellArg cfg.signPath} \
            cert_type=host \
            public_key="$PUBKEY" \
            valid_principals=${lib.escapeShellArg cfg.hostFqdn} \
            ttl=${lib.escapeShellArg cfg.ttl})

          echo "$RESP" | jq -r '.data.signed_key' > ${lib.escapeShellArg cfg.certPath}.new
          # OpenSSH refuses certs with mode broader than the pubkey.
          chmod 0644 ${lib.escapeShellArg cfg.certPath}.new
          mv ${lib.escapeShellArg cfg.certPath}.new ${lib.escapeShellArg cfg.certPath}

          echo "signed SSH host cert for ${cfg.hostFqdn}"
        '';
      };

      # Tell sshd to present the cert. The host key path is the
      # standard one openssh already loads via HostKey.
      services.openssh.extraConfig = ''
        HostCertificate ${cfg.certPath}
      '';
    };
}
