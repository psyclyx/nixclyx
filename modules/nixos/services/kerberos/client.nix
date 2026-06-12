# Kerberos client configuration — writes /etc/krb5.conf.
#
# Sets the default realm and KDC list. The derived/kerberos.nix
# projection drives this from `globals.kerberos` so every host that
# needs Kerberos identity (NFS client, KDC host, etc.) gets a
# consistent realm + KDC list.
#
# We use NixOS's services.kerberos_client under the hood — it
# generates /etc/krb5.conf from a structured attrset. Our wrapper
# just shapes the fleet-side data into that schema.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "kerberos-client"
  ];
  description = "Kerberos client (krb5.conf) configuration";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "Kerberos client configuration";

      realm = lib.mkOption {
        type = lib.types.str;
        description = "Kerberos realm name (e.g. PSYCLYX.NET).";
      };

      kdcs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          Ordered list of KDC hostnames/addresses (port 88). First
          entry is preferred; libkrb5 falls through on failure.
        '';
      };

      adminServer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          kadmin server hostname/address (port 749). Null = same as
          first KDC. Set explicitly when kadmin lives elsewhere.
        '';
      };

      domainRealmMappings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          DNS domain → realm mappings. Used so that referring to a
          principal by hostname automatically picks the right realm.
          E.g. { ".psyclyx.net" = realm; "psyclyx.net" = realm; }.
        '';
      };
    };

  config =
    {
      cfg,
      lib,
      ...
    }:
    lib.mkIf cfg.enable {
      security.krb5 = {
        enable = true;
        settings = {
          libdefaults = {
            default_realm = cfg.realm;
            # Encryption types: AES is enough; RC4/DES skipped.
            default_tkt_enctypes = "aes256-cts-hmac-sha384-192 aes128-cts-hmac-sha256-128 aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96";
            default_tgs_enctypes = "aes256-cts-hmac-sha384-192 aes128-cts-hmac-sha256-128 aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96";
            permitted_enctypes = "aes256-cts-hmac-sha384-192 aes128-cts-hmac-sha256-128 aes256-cts-hmac-sha1-96 aes128-cts-hmac-sha1-96";
            # Forwardable tickets are useful for NFSv4 + ssh forwarding.
            forwardable = true;
            # rdns off is the modern default; matches realm by the
            # canonical name we request, not the reverse-resolved one.
            rdns = false;
            # DNS lookups for KDC: off by default — we drive KDC list
            # from data, not SRV records.
            dns_lookup_kdc = false;
            dns_lookup_realm = false;
          };

          realms.${cfg.realm} = {
            kdc = cfg.kdcs;
            admin_server =
              if cfg.adminServer != null
              then cfg.adminServer
              else builtins.head cfg.kdcs;
          };

          domain_realm = cfg.domainRealmMappings;
        };
      };
    };
}
