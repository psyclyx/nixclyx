# Entity type: OpenBao PKI role.
#
# A PKI mount role declared as data. The fleet projection emits the
# matching `bao write pki/roles/<name>` call from this entity.
{
  egregoreType = { lib, ... }: {
    name = "openbao-pki-role";
    description = "An OpenBao PKI role for issuing leaf certs.";

    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          PKI role name. Required for real entries (asserted).
        '';
      };
      mount = lib.mkOption {
        type = lib.types.str;
        default = "pki";
        description = "PKI mount this role lives under.";
      };
      allowedDomains = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Domains whose names this role is allowed to sign certs for.
          Combined with `allowSubdomains` to determine the cert CN.
        '';
      };
      allowSubdomains = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      allowIpSans = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      clientFlag = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Issue certs with the TLS Web Client Auth EKU.";
      };
      serverFlag = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Issue certs with the TLS Web Server Auth EKU.";
      };
      maxTtl = lib.mkOption {
        type = lib.types.str;
        default = "720h";
      };
    };

    attrs =
      name: entity: _top:
      let
        r = entity.openbao-pki-role;
      in
      {
        label = r.name;
        fullPath = "${r.mount}/roles/${r.name}";
      };

    assertions =
      name: entity: _top:
      let
        r = entity.openbao-pki-role;
      in
      [
        {
          assertion = r.name != "";
          message = "openbao-pki-role '${name}' requires a non-empty name";
        }
        {
          assertion = r.allowedDomains != [ ];
          message = "openbao-pki-role '${name}' requires at least one allowedDomain";
        }
      ];
  };
}
