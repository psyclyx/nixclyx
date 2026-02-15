{
  path = ["psyclyx" "nixos" "services" "grafana"];
  description = "Visualization and dashboarding tool";
  options = {lib, ...}: {
    listen = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address the http server binds to.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 2134;
        description = "Port the http server binds to.";
      };
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Domain the server runs on.";
    };
    oidc = {
      enable = lib.mkEnableOption "OIDC authentication";
      name = lib.mkOption {
        type = lib.types.str;
        default = "Login";
        description = "Display name for the OIDC provider on the login page.";
      };
      issuer = lib.mkOption {
        type = lib.types.str;
        description = "OIDC issuer URL (e.g. https://login.example.com).";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        description = "OIDC client ID.";
      };
      clientSecretFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the OIDC client secret.";
      };
      autoLogin = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically redirect to the OIDC provider.";
      };
    };
  };

  config = {
    cfg,
    lib,
    ...
  }: {
    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = cfg.listen.address;
          http_port = cfg.listen.port;
          enable_gzip = true;
          domain = lib.mkIf (cfg.domain != null) cfg.domain;
          enforce_domain = lib.mkIf (cfg.domain != null) true;
          root_url = lib.mkIf (cfg.domain != null) "https://${cfg.domain}/";
        };
        analytics.reporting_enabled = false;
        "auth.generic_oauth" = lib.mkIf cfg.oidc.enable {
          enabled = true;
          name = cfg.oidc.name;
          client_id = cfg.oidc.clientId;
          client_secret = "$__file{${cfg.oidc.clientSecretFile}}";
          auth_url = "${cfg.oidc.issuer}/oidc/authorize";
          token_url = "${cfg.oidc.issuer}/oidc/token";
          api_url = "${cfg.oidc.issuer}/oidc/userinfo";
          scopes = "openid profile email";
          login_attribute_path = "sub";
          name_attribute_path = "name";
          allow_sign_up = true;
          auto_login = cfg.oidc.autoLogin;
          use_pkce = false;
        };
      };
    };
  };
}
