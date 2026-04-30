# Entity type: HA group (keepalived VIP + load-balanced services).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "ha-group";
  topConfig = config;
  description = "High-availability group with virtual IP and load-balanced services.";

  options = {
    network = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Network entity where the VIP lives.";
    };
    vip = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ipv4 = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          ipv6 = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      };
      default = { };
    };
    vrid = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
    members = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Member host entity names.";
    };
    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
            backendPort = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "http";
            };
            check = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            checkPort = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
            };
            checkSsl = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
      );
      default = { };
    };
  };

  attrs =
    _name: entity: _top:
    let
      ha = entity.ha-group;
      defaultServiceMeta = {
        postgresql = {
          port = 5432;
          checkPort = 8008;
          mode = "tcp";
          check = "/primary";
        };
        redis = {
          port = 6379;
          mode = "tcp";
        };
        openbao = {
          port = 8200;
          check = "/v1/sys/health?standbyok=true";
          mode = "http";
        };
        s3 = {
          port = 8333;
          check = "/status";
          mode = "http";
        };
        webdav = {
          port = 7333;
          mode = "http";
        };
      };
      resolvedServices = lib.mapAttrs (name: svc: (defaultServiceMeta.${name} or { }) // svc) ha.services;
    in
    {
      vip = ha.vip.ipv4;
      vrid = ha.vrid;
      memberCount = builtins.length ha.members;
      label = "VIP ${ha.vip.ipv4} (${toString (builtins.length ha.members)} members)";
      services = resolvedServices;
    };

  assertions =
    name: entity: top:
    let
      ha = entity.ha-group;
    in
    map (member: {
      assertion = top.entities ? ${member};
      message = "ha-group '${name}' member '${member}' does not exist";
    }) ha.members
    ++ [
      {
        assertion = top.entities ? ${ha.network};
        message = "ha-group '${name}' network '${ha.network}' does not exist";
      }
    ];
}
