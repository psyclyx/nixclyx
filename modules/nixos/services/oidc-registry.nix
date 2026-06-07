# Generic OIDC provider registry.
#
# Pure schema: declares the `psyclyx.oidc.*` option tree that consumers
# read to discover the fleet's OIDC issuer / JWKS / discovery URL.
# Population is left to whatever projection knows about the fleet's
# auth service.
{
  path = [ "psyclyx" "oidc" ];
  gate = "always";

  options = { lib, ... }: {
    issuer = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        OIDC issuer URL (e.g. https://login.example.com). Empty if the
        fleet declares no auth-stack service.
      '';
    };
    jwksUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "JWKS endpoint URL for verifying tokens issued by the auth provider.";
    };
    discoveryUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "OIDC discovery document URL (.well-known/openid-configuration).";
    };
    cookieDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Shared cookie domain for SSO across sibling subdomains, if any.";
    };
  };
}
