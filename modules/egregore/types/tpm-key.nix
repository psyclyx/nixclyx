# Entity type: TPM-backed key.
#
# A keypair generated and held by a host's TPM, exposed via PKCS#11.
# Today's single use is iyr's openbao seal-oracle, but typed as a
# fleet entity so (a) the projection can derive the first-boot
# provisioning service, (b) other consumers (a second openbao
# instance, a TPM-backed SSH CA) can ref the same or sibling keys,
# and (c) "which hosts have provisioned TPM keys?" is a queryable
# fact about the fleet.
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "tpm-key";
  topConfig = config;
  description = "A PKCS#11 key generated and held by a host's TPM.";

  options = {
    label = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        PKCS#11 key label. Required (asserted non-empty); empty
        default exists so non-tpm-key entities don't trip the
        option-without-default check.
      '';
    };
    keyType = lib.mkOption {
      type = lib.types.enum [ "rsa" "ec" ];
      default = "rsa";
      description = "Algorithm family for the keypair.";
    };
    bits = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = ''
        Key size (rsa: 2048/3072/4096; ec: 256/384). The projection
        passes this to pkcs11-tool at generation time.
      '';
    };
  };

  attrs =
    name: entity: _top:
    let
      k = entity.tpm-key;
    in
    {
      label = "${k.label} (${k.keyType}-${toString k.bits}) @ ${entity.refs.host or "<?>"}";
      producer = entity.refs.host or null;
    };

  assertions =
    name: entity: top:
    let
      k = entity.tpm-key;
      host = entity.refs.host or null;
    in
    [
      {
        assertion = k.label != "";
        message = "tpm-key '${name}' requires a non-empty label";
      }
      {
        assertion = host != null;
        message = "tpm-key '${name}' requires refs.host";
      }
      {
        assertion = host == null || (top.entities ? ${host} && top.entities.${host}.type == "host");
        message = "tpm-key '${name}' refs.host '${toString host}' must be a host entity";
      }
    ];
}
