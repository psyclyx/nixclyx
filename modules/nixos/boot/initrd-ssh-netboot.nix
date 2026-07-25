# SSH into a netboot initrd, without baking a secret into the image.
#
# A netboot initrd is a public artifact (iyr serves the same image over
# plain HTTP to every PXE client), so it can't carry a confidential host
# key. Instead we generate a *fresh* host key at boot and, optionally,
# have OpenBao sign it against the fleet ssh-host CA — the same trust
# model the microvm guests use (@cert-authority client-side), and the
# same "recover a secret at boot via tang, nothing confidential in the
# image" pattern clevis already gives us for the ZFS unlock.
#
# Two layers, independently useful:
#   - Layer 1 (always): ssh-keygen a throwaway ed25519 host key in the
#     initrd and start sshd on it. Connect with `accept-new`. No baked
#     key, no OpenBao, no clevis — just remote recovery of a wedged
#     initrd. This alone turns "drive to the iLO" into "ssh in".
#   - Layer 2 (`signing` set): clevis-decrypt an OpenBao AppRole
#     secret-id against tang, AppRole-login, and POST the fresh pubkey
#     to the ssh-host sign endpoint. sshd then presents the CA-signed
#     cert (HostCertificate) so clients trust it via the CA with no
#     known_hosts churn. Every step is best-effort: if tang/OpenBao is
#     unreachable, sshd still comes up on the bare key (accept-new), so
#     the recovery path never depends on the fleet being healthy.
{
  path = [ "psyclyx" "nixos" "boot" "initrd-ssh-netboot" ];
  description = "Ephemeral-key (optionally OpenBao-signed) SSH into a netboot initrd";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "SSH access into the netboot initrd";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8022;
        description = "Port the initrd sshd listens on (killed before switch_root).";
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Public keys allowed into the initrd. Empty means "inherit
          root's authorized keys" (resolved in config below).
        '';
      };

      signing = lib.mkOption {
        default = null;
        description = ''
          Optional OpenBao ssh-host-cert signing. null → layer 1 only
          (bare ephemeral key). Requires clevis in the initrd (the
          storage/clevis projection already puts it there for ZFS).
        '';
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              vaultAddr = lib.mkOption {
                type = lib.types.str;
                example = "https://10.0.25.1:8200";
                description = "OpenBao API endpoint reachable from the initrd.";
              };
              insecureSkipVerify = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Skip TLS verification of the OpenBao listener cert.";
              };
              signPath = lib.mkOption {
                type = lib.types.str;
                example = "ssh-host/sign/initrd";
                description = "OpenBao path the pubkey is POSTed to for signing.";
              };
              principal = lib.mkOption {
                type = lib.types.str;
                example = "lab-4-initrd";
                description = "valid_principals put in the signed host cert.";
              };
              ttl = lib.mkOption {
                type = lib.types.str;
                default = "1h";
                description = "Requested cert TTL (role max_ttl bounds it).";
              };
              roleId = lib.mkOption {
                type = lib.types.str;
                description = "AppRole role_id (an identifier, not a secret).";
              };
              secretIdJwe = lib.mkOption {
                type = lib.types.path;
                description = ''
                  clevis JWE wrapping the AppRole secret-id. Baked into
                  the initrd; useless without reaching tang (same as the
                  ZFS unlock blob). Decrypted at boot to log in.
                '';
              };
            };
          }
        );
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf cfg.enable (
      let
        keyPath = "/etc/ssh/initrd_host_ed25519_key";
        certPath = "/etc/ssh/initrd_host_ed25519_key-cert.pub";
        # sshd Includes this. Always created (empty when unsigned) so a
        # literal Include of a missing file can't wedge sshd startup.
        certInclude = "/etc/ssh/initrd_hostcert.conf";
        s = cfg.signing;

        # Best-effort signing. Runs in a subshell so a failure at any
        # step returns non-zero without aborting the outer keygen script.
        signBlock = lib.optionalString (s != null) ''
          sign() (
            set -euo pipefail
            curl=(${pkgs.curl}/bin/curl -sS --fail --max-time 15 ${lib.optionalString s.insecureSkipVerify "--insecure"})
            secret_id=$(${pkgs.clevis}/bin/clevis decrypt < ${s.secretIdJwe})
            [ -n "$secret_id" ]
            token=$("''${curl[@]}" -X POST \
              --data "{\"role_id\":\"${s.roleId}\",\"secret_id\":\"$secret_id\"}" \
              ${s.vaultAddr}/v1/auth/approle/login \
              | ${pkgs.jq}/bin/jq -r '.auth.client_token')
            [ -n "$token" ] && [ "$token" != null ]
            pubkey=$(cat ${keyPath}.pub)
            cert=$("''${curl[@]}" -H "X-Vault-Token: $token" -X POST \
              --data "$(${pkgs.jq}/bin/jq -n --arg pk "$pubkey" \
                '{cert_type:"host",public_key:$pk,valid_principals:"${s.principal}",ttl:"${s.ttl}"}')" \
              ${s.vaultAddr}/v1/${s.signPath} \
              | ${pkgs.jq}/bin/jq -r '.data.signed_key')
            [ -n "$cert" ] && [ "$cert" != null ]
            printf '%s\n' "$cert" > ${certPath}
            chmod 0644 ${certPath}
            printf 'HostCertificate %s\n' ${certPath} > ${certInclude}
            echo "initrd-ssh: signed host cert for ${s.principal}"
          )
          sign || echo "initrd-ssh: signing failed/unreachable — bare key only (use accept-new)"
        '';

        prepScript = pkgs.writeShellScript "initrd-ssh-prepare" ''
          set -eu
          umask 077
          mkdir -p /etc/ssh
          : > ${certInclude}
          rm -f ${keyPath} ${keyPath}.pub ${certPath}
          ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f ${keyPath}
          ${signBlock}
        '';
      in
      {
        # sshd needs the initrd network stack up. lab-4 configures the
        # interface via the kernel's ip=dhcp (see derived/pxe.nix — it
        # deliberately avoids initrd networkd to not race clevis-tang),
        # so this doesn't manage any interface; it just gates the ssh
        # module on.
        boot.initrd.network.enable = true;

        boot.initrd.network.ssh = {
          enable = true;
          port = cfg.port;
          # No build-time key — we generate one at boot instead.
          hostKeys = [ ];
          ignoreEmptyHostKeys = true;
          authorizedKeys =
            if cfg.authorizedKeys != [ ]
            then cfg.authorizedKeys
            else config.users.users.root.openssh.authorizedKeys.keys;
          # HostKey points at the runtime-generated key; the cert (if
          # any) comes in via the Include the prepare service writes.
          extraConfig = ''
            HostKey ${keyPath}
            Include ${certInclude}
          '';
        };

        boot.initrd.systemd = {
          storePaths =
            [ prepScript pkgs.openssh ]
            ++ lib.optionals (s != null) [ pkgs.clevis pkgs.curl pkgs.jq ];

          services.initrd-ssh-prepare = {
            description = "Generate (and optionally OpenBao-sign) the initrd SSH host key";
            wantedBy = [ "initrd.target" "sshd.service" ];
            before = [ "sshd.service" ];
            # Ordered after basic network so signing can reach tang/OpenBao.
            # NOT required=network-online: keygen must succeed even if the
            # net never comes up, so sshd (which wants us) can still start.
            after = [ "network.target" ];
            unitConfig.DefaultDependencies = false;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              TimeoutStartSec = "45s";
              ExecStart = prepScript;
            };
          };

          # Make the stock initrd sshd wait for our key to exist. `wants`
          # (not `requires`) so a signing hiccup can't block sshd — the
          # prepare unit still exits 0 as long as the bare key was made.
          services.sshd = {
            after = [ "initrd-ssh-prepare.service" ];
            wants = [ "initrd-ssh-prepare.service" ];
          };
        };
      }
    );
}
