{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.postgresql;

  postgresql =
    if cfg.extraPlugins == [ ] then cfg.package else cfg.package.withPackages (_: cfg.extraPlugins);

  toStr =
    value:
    if true == value then
      "yes"
    else if false == value then
      "no"
    else if isString value then
      "'${lib.replaceStrings [ "'" ] [ "''" ] value}'"
    else
      toString value;

  # The main PostgreSQL configuration file.
  configFile = pkgs.writeText "postgresql.conf" (
    concatStringsSep "\n" (mapAttrsToList (n: v: "${n} = ${toStr v}") cfg.settings)
  );

  # Convert ensureClauses to SQL options for CREATE USER
  clausesToSql =
    clauses:
    concatStringsSep " " (
      mapAttrsToList (name: value: if value == true then name else "${name} ${toStr value}") clauses
    );

  # Create script to create users and assign permissions
  initScript = pkgs.writeShellScript "postgresql-init" ''
    set -e

    # Make sure data directory exists with correct permissions
    if ! test -e "${cfg.dataDir}/PG_VERSION"; then
      mkdir -p ${cfg.dataDir}
      chmod 700 ${cfg.dataDir}
      ${postgresql}/bin/initdb \
        --pgdata=${cfg.dataDir} \
        --username=${cfg.superUser} \
        ${escapeShellArgs cfg.initdbArgs}
    fi

    # Link configuration files
    ln -sf ${configFile} ${cfg.dataDir}/postgresql.conf
    ln -sf ${pkgs.writeText "pg_hba.conf" cfg.authentication} ${cfg.dataDir}/pg_hba.conf
    ln -sf ${pkgs.writeText "pg_ident.conf" cfg.identMap} ${cfg.dataDir}/pg_ident.conf
  '';

  setupScript =
    let
      createDatabases = concatMapStrings (database: ''
        if ! echo "SELECT 1 FROM pg_database WHERE datname = '${database}'" |  PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres -t | grep -q 1; then
          echo "CREATE DATABASE ${database};" | PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres
        fi
      '') cfg.ensureDatabases;

      createUsers = concatMapStrings (
        user:
        let
          userOptions = if user.ensureClauses != { } then "WITH ${clausesToSql user.ensureClauses}" else "";
          passwordOption = if user.password != null then "PASSWORD '${user.password}'" else "";
        in
        ''
          if ! echo "SELECT 1 FROM pg_roles WHERE rolname = '${user.name}'" | PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres -t | grep -q 1; then
            echo "CREATE USER ${user.name} ${userOptions} ${passwordOption};" | PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres
          fi
          ${concatStringsSep "\n" (
            mapAttrsToList (database: permission: ''
              echo "GRANT ${permission} ON ${database} TO ${user.name};" | PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres
            '') user.ensurePermissions
          )}
        ''
      ) cfg.ensureUsers;
    in
    pkgs.writeShellScript "postgresql-setup" ''
      set -e

      # Check if setup has already been completed
      SETUP_MARKER="${cfg.dataDir}/.hm_setup_complete"
      if [ -f "$SETUP_MARKER" ]; then
        # Setup already completed
        exit 0
      fi

      # Configuration
      export PGPORT=${toString cfg.port}

      # Wait for PostgreSQL to be ready
      for i in {1..30}; do
        if ${postgresql}/bin/pg_isready -p $PGPORT; then
          break
        fi
        sleep 1
      done

      # Only proceed if PostgreSQL is actually ready
      if ! ${postgresql}/bin/pg_isready -p $PGPORT; then
        echo "PostgreSQL is not ready, will try again later"
        exit 1
      fi

      # Create databases
      ${createDatabases}

      # Create users and set permissions
      ${createUsers}

      # Run initial script if provided
      ${optionalString (cfg.initialScript != null) ''
        PGPORT="$PGPORT" ${postgresql}/bin/psql -U ${cfg.superUser} -d postgres -f ${cfg.initialScript}
      ''}

      # Mark setup as complete
      touch "$SETUP_MARKER"
    '';
in
{
  options.services.postgresql = {
    enable = mkEnableOption "PostgreSQL Server";

    package = mkOption {
      type = types.package;
      default = pkgs.postgres_17;
      description = "PostgreSQL package to use.";
    };

    port = mkOption {
      type = types.int;
      default = 5432;
      description = "The port on which PostgreSQL listens.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "${config.xdg.dataHome}/postgresql";
      description = "The data directory for PostgreSQL.";
    };

    authentication = mkOption {
      type = types.lines;
      default = ''
        local all all peer
        host all all 127.0.0.1/32 scram-sha-256
        host all all ::1/128 scram-sha-256
      '';
      description = "Defines how users authenticate themselves to the server.";
    };

    identMap = mkOption {
      type = types.lines;
      default = "";
      description = "Defines the mapping from system users to database users.";
    };

    initdbArgs = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [
        "--data-checksums"
        "--allow-group-access"
      ];
      description = "Additional arguments passed to `initdb` during data dir initialization.";
    };

    initialScript = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "A file containing SQL statements to execute on first startup.";
    };

    ensureDatabases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "myapp"
        "myotherapp"
      ];
      description = "Ensures that the specified databases exist.";
    };

    ensureUsers = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Name of the user to ensure.";
            };

            password = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Password for the user (leave as null for no password).";
            };

            ensurePermissions = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Permissions to ensure for the user.";
              example = literalExpression ''
                {
                  "DATABASE myapp" = "ALL PRIVILEGES";
                  "ALL TABLES IN SCHEMA public" = "ALL PRIVILEGES";
                }
              '';
            };

            ensureClauses = mkOption {
              type = types.attrsOf types.anything;
              default = { };
              description = "Additional clauses for CREATE USER.";
              example = literalExpression ''
                {
                  superuser = true;
                  createdb = true;
                  login = true;
                }
              '';
            };
          };
        }
      );
      default = [ ];
      description = "Ensures that the specified users exist with the defined permissions.";
    };

    enableTCPIP = mkOption {
      type = types.bool;
      default = false;
      description = "Whether PostgreSQL should listen on all network interfaces.";
    };

    extraPlugins = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = literalExpression "with pkgs.postgresql_17.pkgs; [ postgis pg_repack ]";
      description = "List of PostgreSQL plugins.";
    };

    settings = mkOption {
      type =
        with types;
        attrsOf (oneOf [
          bool
          float
          int
          str
        ]);
      default = { };
      description = "PostgreSQL configuration settings.";
    };

    superUser = mkOption {
      type = types.str;
      default = config.home.username;
      description = "PostgreSQL superuser account.";
    };
  };

  config = mkIf cfg.enable {
    services.postgresql.settings = {
      hba_file = "${cfg.dataDir}/pg_hba.conf";
      ident_file = "${cfg.dataDir}/pg_ident.conf";
      log_destination = "stderr";
      log_line_prefix = "[%p] ";
      listen_addresses = if cfg.enableTCPIP then "*" else "localhost";
      port = cfg.port;
    };

    # untested
    systemd.user.services = mkIf pkgs.stdenv.isLinux {
      postgresql = {
        Unit = {
          Description = "PostgreSQL Server";
          After = [ "network.target" ];
        };
        Service = {
          Type = "simple";
          ExecStartPre = "${initScript}";
          ExecStart = "${postgresql}/bin/postgres -D ${cfg.dataDir}";
          ExecStop = "${postgresql}/bin/pg_ctl stop -D ${cfg.dataDir} -m fast";
          Restart = "on-failure";
          Environment = [ "PGDATA=${cfg.dataDir}" ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
      postgresql-setup =
        mkIf (cfg.ensureDatabases != [ ] || cfg.ensureUsers != [ ] || cfg.initialScript != null)
          {
            Unit = {
              Description = "PostgreSQL Database Setup";
              After = [ "postgresql.service" ];
              Requires = [ "postgresql.service" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${setupScript}";
              RemainAfterExit = true;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
    };

    launchd.agents = mkIf pkgs.stdenv.isDarwin {
      postgresql = {
        enable = true;
        config = {
          Label = "org.postgresql.server";
          ProgramArguments = [
            "${pkgs.bash}/bin/bash"
            "-c"
            "${initScript} && exec ${postgresql}/bin/postgres -D ${cfg.dataDir}"
          ];
          KeepAlive = true;
          RunAtLoad = true;
          StandardErrorPath = "${cfg.dataDir}/../postgres.log";
          StandardOutPath = "${cfg.dataDir}/../postgres.log";
          EnvironmentVariables = {
            PGDATA = cfg.dataDir;
          };
        };
      };

      postgresql-setup =
        mkIf (cfg.ensureDatabases != [ ] || cfg.ensureUsers != [ ] || cfg.initialScript != null)
          {
            enable = true;
            config = {
              Label = "org.postgresql.setup";
              ProgramArguments = [ "${setupScript}" ];
              RunAtLoad = true;
              StandardErrorPath = "${cfg.dataDir}/../postgres-setup.log";
              StandardOutPath = "${cfg.dataDir}/../postgres-setup.log";
              EnvironmentVariables = {
                PGDATA = cfg.dataDir;
              };
            };
          };
    };
  };
}
