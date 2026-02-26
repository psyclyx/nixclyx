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
      roleAttributePath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "JMESPath expression to map OIDC userinfo claims to Grafana roles.";
      };
    };
    secretKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to file containing the secret key used for signing data source settings.";
    };
    dashboards = {
      enable = lib.mkEnableOption "built-in homelab monitoring dashboards";
      extraProviders = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        description = "Additional dashboard provider configs.";
      };
    };
  };

  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: let
    dsl = import ./dashboards/lib.nix;
    dashboardFiles = {
      "overview.json" = import ./dashboards/overview.nix dsl;
      "nodes.json" = import ./dashboards/nodes.nix dsl;
      "hardware.json" = import ./dashboards/hardware.nix dsl;
      "storage.json" = import ./dashboards/storage.nix dsl;
      "postgresql.json" = import ./dashboards/postgresql.nix dsl;
      "redis.json" = import ./dashboards/redis.nix dsl;
      "seaweedfs.json" = import ./dashboards/seaweedfs.nix dsl;
      "network.json" = import ./dashboards/network.nix dsl;
      "bcachefs.json" = import ./dashboards/bcachefs.nix dsl;
      "etcd.json" = import ./dashboards/etcd.nix dsl;
      "patroni.json" = import ./dashboards/patroni.nix dsl;
      "haproxy.json" = import ./dashboards/haproxy.nix dsl;
    };
    dashboardDir = pkgs.linkFarm "grafana-dashboards" (
      lib.mapAttrsToList (name: dashboard: {
        inherit name;
        path = pkgs.writeText name (builtins.toJSON dashboard);
      }) dashboardFiles
    );
  in {
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
        security.secret_key = "$__file{${cfg.secretKeyFile}}";
        dashboards.default_home_dashboard_path =
          lib.mkIf cfg.dashboards.enable "${dashboardDir}/overview.json";
        analytics.reporting_enabled = false;
        "auth.anonymous".enabled = true;
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
          role_attribute_path = lib.mkIf (cfg.oidc.roleAttributePath != null) cfg.oidc.roleAttributePath;
        };
      };
      provision.dashboards.settings.providers =
        (lib.optional cfg.dashboards.enable {
          name = "psyclyx";
          type = "file";
          disableDeletion = true;
          options.path = dashboardDir;
        })
        ++ cfg.dashboards.extraProviders;
    };
  };
}
