{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = [ config.services.postgresql.package ];
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = false;
    authentication = lib.mkForce ''
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
      local all all trust
    '';

    ensureUsers = [
      {
        name = "developer";
        password = "local-dev-only!_not-secret!_dont-reuse!_dont-expose-to-network!";
        ensureClauses = {
          superuser = true;
          createdb = true;
          login = true;
        };
      }
    ];
  };
}
