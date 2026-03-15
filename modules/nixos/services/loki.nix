{
  path = ["psyclyx" "nixos" "services" "loki"];
  description = "Loki log aggregation server";
  options = {lib, ...}: {
    port = lib.mkOption {
      type = lib.types.port;
      default = 3100;
      description = "HTTP listen port for the Loki server.";
    };
    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "744h";
      description = "Log retention period.";
    };
  };
  config = {cfg, ...}: {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = "0.0.0.0";
          http_listen_port = cfg.port;
        };
        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
        };
        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        limits_config.retention_period = cfg.retentionPeriod;
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };
    psyclyx.nixos.network.ports.loki = cfg.port;
  };
}
