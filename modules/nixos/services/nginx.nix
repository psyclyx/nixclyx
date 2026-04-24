{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "nginx"
  ];
  description = "nginx web server with Let's Encrypt";
  options =
    { lib, ... }:
    {
      acme = {
        email = lib.mkOption {
          type = lib.types.str;
          description = "Email for Let's Encrypt registration";
        };
      };
      virtualHosts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              root = lib.mkOption {
                type = lib.types.nullOr lib.types.path;
                default = null;
                description = "Document root for static files";
              };
              locations = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submodule {
                    options = {
                      proxyPass = lib.mkOption {
                        type = lib.types.nullOr lib.types.str;
                        default = null;
                        description = "Proxy requests to this URL";
                      };
                      root = lib.mkOption {
                        type = lib.types.nullOr lib.types.path;
                        default = null;
                        description = "Document root for this location";
                      };
                    };
                  }
                );
                default = { };
                description = "Location blocks";
              };
            };
          }
        );
        default = { };
        description = "Virtual hosts to configure (keys are domain names)";
      };
      staticSites = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              root = lib.mkOption {
                type = lib.types.path;
                description = "Document root for static files";
              };
              port = lib.mkOption {
                type = lib.types.port;
                description = "Localhost port to listen on.";
              };
            };
          }
        );
        default = { };
        description = "Localhost-only static file virtual hosts (no TLS).";
      };
    };
  config =
    {
      cfg,
      config,
      lib,
      ...
    }:
    let
      domains = builtins.attrNames cfg.virtualHosts;
    in
    {
      psyclyx.nixos.network.ports.nginx = [
        80
        443
      ];

      security.acme = {
        acceptTerms = true;
        defaults.email = cfg.acme.email;
      };

      services.nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts =
          builtins.mapAttrs (domain: hostCfg: {
            enableACME = true;
            forceSSL = true;
            root = hostCfg.root;
            locations = builtins.mapAttrs (path: locCfg: {
              proxyPass = locCfg.proxyPass;
              root = locCfg.root;
            }) hostCfg.locations;
          }) cfg.virtualHosts
          // builtins.mapAttrs (domain: siteCfg: {
            listen = [
              {
                addr = "127.0.0.1";
                port = siteCfg.port;
              }
            ];
            root = siteCfg.root;
          }) cfg.staticSites;
      };
    };
}
