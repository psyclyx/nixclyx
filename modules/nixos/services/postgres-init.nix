# Generic PostgreSQL bootstrap: declarative roles, tablespaces,
# databases, extensions, and schemas, applied idempotently after
# postgresql.service starts.
#
# Roles' passwords are read from on-disk files (typically rendered
# from a secret store) — re-running the unit rotates passwords to
# whatever the files currently contain. Database creation honors
# per-DB tablespace and encoding; CREATE EXTENSION is gated on
# IF NOT EXISTS, so the unit is safe to re-run after manual changes.
#
# The unit emits one psql session per logical step (DO-block for
# roles, top-level CREATE DATABASE statements via \gexec, per-DB
# extension + schema setup), so a failure in one block doesn't
# torpedo earlier ones.
{
  path = [ "psyclyx" "nixos" "services" "postgres-init" ];
  description = "Declarative roles / databases / tablespaces / extensions for a local PostgreSQL.";

  options = { lib, ... }: {
    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "pkgs.postgresql";
      description = "PostgreSQL package whose psql binary runs the init script.";
    };

    superuser = lib.mkOption {
      type = lib.types.str;
      default = "postgres";
      description = "Local OS user that owns the postgresql server and runs the init unit.";
    };

    roles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          passwordFile = lib.mkOption {
            type = lib.types.str;
            description = ''
              Path to a file containing the role's password. Read each
              time the unit runs; rotation = update the file +
              restart the unit. Empty file => role skipped (warning).
            '';
          };
        };
      });
      default = { };
      description = "Login roles to create/update, keyed by role name.";
    };

    tablespaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          location = lib.mkOption {
            type = lib.types.str;
            description = ''
              Filesystem path PostgreSQL will use for this tablespace.
              The directory must exist and be 0700-owned by the
              postgres user before the unit runs (set up via
              systemd.tmpfiles.rules in the caller).
            '';
          };
        };
      });
      default = { };
      description = "Tablespaces to create, keyed by tablespace name.";
    };

    databases = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          owner = lib.mkOption {
            type = lib.types.str;
            description = "Role that owns the database. Must be declared in `roles`.";
          };
          encoding = lib.mkOption {
            type = lib.types.str;
            default = "UTF8";
            description = "Server-side encoding.";
          };
          tablespace = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "If set, place the database on this tablespace (must be declared in `tablespaces`).";
          };
        };
      });
      default = { };
      description = "Databases to create, keyed by DB name.";
    };

    extensions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Extension name (e.g. \"cube\", \"unaccent\").";
          };
          schema = lib.mkOption {
            type = lib.types.str;
            default = "public";
            description = "Schema the extension is installed into.";
          };
        };
      }));
      default = { };
      description = "Extensions to install per database (keyed by DB name). Installed as the cluster superuser.";
    };

    schemas = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.submodule {
        options = {
          owner = lib.mkOption {
            type = lib.types.str;
            description = "Role that owns the schema.";
          };
        };
      }));
      default = { };
      description = "Schemas to create per database. Outer attrset keyed by DB name, inner by schema name.";
    };

    extraAfter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra systemd units the init unit should run After=.";
    };

    extraWants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra systemd units the init unit should Wants=.";
    };
  };

  config = { cfg, lib, pkgs, ... }: let
    enabled = cfg.enable;
    psql = "${cfg.package}/bin/psql";

    sqlQuote = s: lib.replaceStrings [ "'" ] [ "''" ] s;

    roleBlock = roleName: role: ''
      pw="$(cat ${lib.escapeShellArg role.passwordFile})"
      if [ -z "$pw" ]; then
        echo "warning: empty password for ${roleName} in ${role.passwordFile}, skipping" >&2
      else
        ${psql} -v ON_ERROR_STOP=1 -d postgres <<SQL
          DO \$\$
          BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${sqlQuote roleName}') THEN
              CREATE ROLE "${sqlQuote roleName}" LOGIN PASSWORD '$pw';
            ELSE
              ALTER ROLE "${sqlQuote roleName}" WITH LOGIN PASSWORD '$pw';
            END IF;
          END
          \$\$;
      SQL
      fi
    '';

    # CREATE TABLESPACE can't run inside a DO block, so use \gexec.
    # $sql$..$sql$ dollar-quoting keeps the path literal apostrophes
    # from fighting both SQL and Nix quote escaping.
    tablespaceBlock = tsName: ts: ''
      ${psql} -v ON_ERROR_STOP=1 -d postgres <<SQL
        SELECT \$sql\$CREATE TABLESPACE ${sqlQuote tsName} LOCATION '${sqlQuote ts.location}'\$sql\$
        WHERE NOT EXISTS (SELECT 1 FROM pg_tablespace WHERE spcname = '${sqlQuote tsName}')\gexec
      SQL
    '';

    databaseBlock = dbName: db: let
      tablespaceClause =
        if db.tablespace != null
        then " TABLESPACE ${sqlQuote db.tablespace}"
        else "";
      ddl = "CREATE DATABASE \"${sqlQuote dbName}\" OWNER \"${sqlQuote db.owner}\" ENCODING ${sqlQuote db.encoding}${tablespaceClause}";
    in ''
      ${psql} -v ON_ERROR_STOP=1 -d postgres <<SQL
        SELECT '${ddl}'
        WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${sqlQuote dbName}')\gexec
      SQL
    '';

    extensionsBlock = dbName: exts: ''
      ${psql} -v ON_ERROR_STOP=1 -d ${lib.escapeShellArg dbName} <<SQL
      ${lib.concatMapStringsSep "\n" (e:
        "  CREATE EXTENSION IF NOT EXISTS ${sqlQuote e.name} WITH SCHEMA ${sqlQuote e.schema};"
      ) exts}
      SQL
    '';

    schemasBlock = dbName: schemas: ''
      ${psql} -v ON_ERROR_STOP=1 -d ${lib.escapeShellArg dbName} <<SQL
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (schName: sch: ''
        CREATE SCHEMA IF NOT EXISTS "${sqlQuote schName}";
        ALTER SCHEMA "${sqlQuote schName}" OWNER TO "${sqlQuote sch.owner}";
      '') schemas)}
      SQL
    '';

    initScript = pkgs.writeShellScript "postgres-init" ''
      set -euo pipefail
      ${lib.concatStrings (lib.mapAttrsToList roleBlock cfg.roles)}
      ${lib.concatStrings (lib.mapAttrsToList tablespaceBlock cfg.tablespaces)}
      ${lib.concatStrings (lib.mapAttrsToList databaseBlock cfg.databases)}
      ${lib.concatStrings (lib.mapAttrsToList extensionsBlock cfg.extensions)}
      ${lib.concatStrings (lib.mapAttrsToList schemasBlock cfg.schemas)}
    '';

    badOwners = lib.filter (db: !(cfg.roles ? ${db.owner})) (lib.attrValues cfg.databases);
    badTablespaces = lib.filter (db:
      db.tablespace != null && !(cfg.tablespaces ? ${db.tablespace})
    ) (lib.attrValues cfg.databases);
  in lib.mkIf enabled {
    assertions = [
      {
        assertion = badOwners == [];
        message = "psyclyx.nixos.services.postgres-init: database owner not declared in roles: ${lib.concatMapStringsSep ", " (d: d.owner) badOwners}";
      }
      {
        assertion = badTablespaces == [];
        message = "psyclyx.nixos.services.postgres-init: database tablespace not declared in tablespaces: ${lib.concatMapStringsSep ", " (d: d.tablespace) badTablespaces}";
      }
    ];

    systemd.services.postgres-init = {
      description = "Bootstrap PostgreSQL roles / databases / tablespaces / extensions / schemas";
      after = [ "postgresql.service" ] ++ cfg.extraAfter;
      requires = [ "postgresql.service" ];
      wants = cfg.extraWants;
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.superuser;
        Group = cfg.superuser;
        ExecStart = "${initScript}";
        RemainAfterExit = true;
      };
    };
  };
}
