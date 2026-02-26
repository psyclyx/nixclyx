{
  path = ["psyclyx" "nixos" "services" "attic"];
  description = "Attic Nix binary cache server";
  options = {lib, ...}: {
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Hostnames of all nodes running atticd.";
    };
    listenNetwork = lib.mkOption {
      type = lib.types.str;
      default = "rack";
      description = "Topology network for the HTTP listen address.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "HTTP port for the attic server.";
    };
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "data";
      description = "Topology network for PostgreSQL/S3 connections.";
    };
    database = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "attic";
        description = "PostgreSQL database name.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "attic";
        description = "PostgreSQL user.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the database password.";
      };
      superuserPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the PostgreSQL superuser password (for db-init).";
      };
    };
    storage = {
      bucket = lib.mkOption {
        type = lib.types.str;
        default = "attic";
        description = "S3 bucket name for chunk storage.";
      };
      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "S3 endpoint URL (derived from topology if null).";
      };
      credentialsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to env file with AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.";
      };
    };
    tokenSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to file containing the HS256 JWT signing secret (shared across all nodes).";
    };
  };

  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    topo = config.psyclyx.topology;
    topoLib = topo.enriched;
    hostname = config.psyclyx.nixos.host;
    labIdx = topo.hosts.${hostname}.labIndex;

    listenNet = topoLib.networks.${cfg.listenNetwork};
    dataNet = topoLib.networks.${cfg.dataNetwork};

    listenAddr = "${listenNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";
    dataAddr = "${dataNet.prefix}.${toString (topo.conventions.hostBaseOffset + labIdx)}";

    clusterLabIndices = map (name: topo.hosts.${name}.labIndex) cfg.clusterNodes;
    sortedIndices = builtins.sort builtins.lessThan clusterLabIndices;
    isFirst = labIdx == builtins.head sortedIndices;

    # PostgreSQL via HAProxy VIP (Patroni routes to current primary)
    labGroup = topo.haGroups.lab;
    haNet = topoLib.networks.${labGroup.network};
    pgVip = "${haNet.prefix}.${toString labGroup.vipOffset}";

    s3Endpoint =
      if cfg.storage.endpoint != null
      then cfg.storage.endpoint
      else "http://${dataAddr}:8333";

    configDir = "/run/atticd";

    atticd = "${pkgs.attic-server}/bin/atticd";

    # Build-time TOML template. DB password placeholder is substituted at runtime.
    configTemplate = pkgs.writeText "attic-server.toml" (''
      listen = "${listenAddr}:${toString cfg.port}"

      [database]
      url = "postgresql://${cfg.database.user}:__DB_PASSWORD__@${pgVip}:5432/${cfg.database.name}"

      [storage]
      type = "s3"
      bucket = "${cfg.storage.bucket}"
      endpoint = "${s3Endpoint}"
      region = "us-east-1"

      [chunking]
      nar-size-threshold = 65536
      min-size = 16384
      avg-size = 65536
      max-size = 262144

      [compression]
      type = "zstd"

      [garbage-collection]
      interval = "24 hours"
      default-retention-period = "6 months"
    '' + lib.optionalString (cfg.tokenSecretFile != null) ''

      [jwt.signing]
      token-hs256-secret-base64 = "__TOKEN_SECRET_B64__"
    '');

    setupScript = pkgs.writeShellScript "atticd-setup" ''
      set -euo pipefail
      umask 077
      cp ${configTemplate} ${configDir}/server.toml

      # Substitute database password
      if [ -n "${toString cfg.database.passwordFile}" ] && [ -f "${toString cfg.database.passwordFile}" ]; then
        DB_PASS=$(cat "${toString cfg.database.passwordFile}" | ${pkgs.coreutils}/bin/tr -d '\n')
        ${pkgs.gnused}/bin/sed -i "s|__DB_PASSWORD__|''${DB_PASS}|" ${configDir}/server.toml
      fi

      # Substitute token secret (base64-encoded)
      if [ -n "${toString cfg.tokenSecretFile}" ] && [ -f "${toString cfg.tokenSecretFile}" ]; then
        TOKEN_B64=$(${pkgs.coreutils}/bin/base64 -w0 < "${toString cfg.tokenSecretFile}")
        ${pkgs.gnused}/bin/sed -i "s|__TOKEN_SECRET_B64__|''${TOKEN_B64}|" ${configDir}/server.toml
      fi
    '';
  in {
    environment.systemPackages = [pkgs.attic-client];

    systemd.services.atticd = {
      description = "Attic Nix binary cache server";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        RuntimeDirectory = "atticd";
        StateDirectory = "atticd";
        ExecStartPre = ["+${setupScript}"];
        ExecStart = "${atticd} -f ${configDir}/server.toml";
        EnvironmentFile = lib.mkIf (cfg.storage.credentialsFile != null)
          cfg.storage.credentialsFile;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Database init on primary node only.
    systemd.services.atticd-db-init = lib.mkIf isFirst {
      description = "Initialize Attic PostgreSQL database";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      before = ["atticd.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        pgHost = pgVip;
      in ''
        # Authenticate as superuser via PGPASSWORD
        ${lib.optionalString (cfg.database.superuserPasswordFile != null) ''
          export PGPASSWORD="$(cat "${cfg.database.superuserPasswordFile}" | ${pkgs.coreutils}/bin/tr -d '\n')"
        ''}

        # Wait for PostgreSQL to be ready
        for i in $(seq 1 60); do
          if ${pkgs.postgresql}/bin/pg_isready -h ${pgHost} -p 5432 -q; then
            break
          fi
          sleep 2
        done

        # Create role and database if they don't exist
        ${pkgs.postgresql}/bin/psql -h ${pgHost} -U postgres -tc \
          "SELECT 1 FROM pg_roles WHERE rolname='${cfg.database.user}'" | \
          grep -q 1 || \
          ${pkgs.postgresql}/bin/psql -h ${pgHost} -U postgres -c \
            "CREATE ROLE ${cfg.database.user} WITH LOGIN PASSWORD '$(cat ${toString cfg.database.passwordFile})';"

        ${pkgs.postgresql}/bin/psql -h ${pgHost} -U postgres -tc \
          "SELECT 1 FROM pg_database WHERE datname='${cfg.database.name}'" | \
          grep -q 1 || \
          ${pkgs.postgresql}/bin/psql -h ${pgHost} -U postgres -c \
            "CREATE DATABASE ${cfg.database.name} OWNER ${cfg.database.user};"
      '';
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
