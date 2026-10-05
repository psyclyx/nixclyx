# Publish ACME-issued certs to OpenBao KV.
#
# Hosts that issue certs locally (security.acme + DNS authority) hook
# into each cert's postRun to push the renewed cert+key into the lab
# OpenBao KV. Other hosts (consumers) fetch via openbao-kv and reload
# their TLS terminators.
#
# A single KV entry per cert holds the haproxy-style "full.pem"
# (private key followed by full chain).
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-cert-publish"
  ];
  description = "Publish ACME-issued certs to OpenBao KV";
  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "publish ACME certs to OpenBao KV";

      vaultAddr = lib.mkOption {
        type = lib.types.str;
        description = "OpenBao API endpoint to push certs to.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/openbao-auth/services-token";
        description = "Path to the OpenBao auth token (provisioned by openbao-login).";
      };

      insecureSkipVerify = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Skip TLS verification of the OpenBao server cert.";
      };

      kvMount = lib.mkOption {
        type = lib.types.str;
        default = "kv";
      };

      certs = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            kvPath = lib.mkOption {
              type = lib.types.str;
              description = ''
                KV path (under kvMount) for this cert. Convention:
                "wildcards/<domain>" for shared wildcards.
              '';
            };
          };
        });
        default = { };
        description = ''
          Certs to publish, keyed by cert domain name (matches the
          security.acme.certs attribute name → /var/lib/acme/<key>/).
        '';
      };
    };

  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    let
      bao = "${pkgs.openbao}/bin/bao";
      unitName = domain: "openbao-cert-publish-${lib.replaceStrings [ "." ] [ "-" ] domain}";
    in
    lib.mkIf cfg.enable {
      # postRun only fires when lego actually renews, so a push that
      # failed there was never retried — KV (what consumers fetch) sat on
      # the May cert while tleilax renewed. The push is its own unit:
      # kicked by postRun, re-run daily, and failing loudly.
      security.acme.certs = lib.mapAttrs (domain: _: {
        postRun = "systemctl start --no-block ${unitName domain}.service";
      }) cfg.certs;

      systemd.services = lib.mapAttrs' (
        domain: c:
        lib.nameValuePair (unitName domain) {
          description = "Publish ACME cert ${domain} to OpenBao KV";
          after = [
            "openbao-login.service"
            "acme-${domain}.service"
          ];
          wants = [ "openbao-login.service" ];
          # Also push at boot/activation: otherwise a fixed deploy sits on a
          # stale KV copy until the first timer tick.
          wantedBy = [ "multi-user.target" ];
          startAt = "daily";
          environment = {
            BAO_ADDR = cfg.vaultAddr;
          } // lib.optionalAttrs cfg.insecureSkipVerify {
            VAULT_SKIP_VERIFY = "true";
          };
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            if [ ! -f ${lib.escapeShellArg cfg.tokenFile} ]; then
              echo "openbao-cert-publish: no token at ${cfg.tokenFile}, cannot push ${domain}" >&2
              exit 1
            fi
            export BAO_TOKEN="$(cat ${lib.escapeShellArg cfg.tokenFile})"
            ${bao} kv put -mount=${lib.escapeShellArg cfg.kvMount} ${lib.escapeShellArg c.kvPath} \
              "full=@/var/lib/acme/${domain}/full.pem" \
              "cert=@/var/lib/acme/${domain}/cert.pem" \
              "chain=@/var/lib/acme/${domain}/chain.pem" \
              "fullchain=@/var/lib/acme/${domain}/fullchain.pem" \
              "key=@/var/lib/acme/${domain}/key.pem"
            echo "openbao-cert-publish: published ${domain} → ${cfg.kvMount}/${c.kvPath}"
          '';
        }
      ) cfg.certs;
    };
}
