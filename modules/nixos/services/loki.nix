{
  path = ["psyclyx" "nixos" "services" "loki"];
  description = "Loki log aggregation server";
  config = _: {
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = "0.0.0.0";
          http_listen_port = 3100;
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
        limits_config.retention_period = "744h";
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };
  };
}
