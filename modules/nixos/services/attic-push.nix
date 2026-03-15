{
  path = ["psyclyx" "nixos" "services" "attic-push"];
  description = "Attic nix binary cache client (watch-store + substituter)";
  options = {lib, ...}: {
    endpoint = lib.mkOption {
      type = lib.types.str;
      description = "URL of the Attic server.";
    };
    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "psyclyx";
      description = "Name of the Attic cache to push to.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to file containing the Attic push token.";
    };
    substituter = lib.mkOption {
      type = lib.types.str;
      description = "Nix substituter URL (e.g. http://cache.psyclyx.net:8080/psyclyx).";
    };
    publicKey = lib.mkOption {
      type = lib.types.str;
      description = "Public key for the Attic cache.";
    };
    netrcFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to netrc file for authenticating to the substituter.";
    };
  };
  config = {cfg, lib, pkgs, ...}: {
    environment.systemPackages = [pkgs.attic-client];

    nix.settings = {
      extra-trusted-substituters = [cfg.substituter];
      extra-trusted-public-keys = [cfg.publicKey];
      netrc-file = lib.mkIf (cfg.netrcFile != null) cfg.netrcFile;
    };

    systemd.services.attic-watch-store = {
      description = "Attic Nix store watcher";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        StateDirectory = "attic-watch-store";
        Restart = "always";
        RestartSec = 30;
      };
      script = let
        attic = "${pkgs.attic-client}/bin/attic";
        stateDir = "/var/lib/attic-watch-store";
      in ''
        set -euo pipefail
        TOKEN=$(cat "${cfg.tokenFile}" | ${pkgs.coreutils}/bin/tr -d '\n')
        umask 077
        mkdir -p ${stateDir}/attic
        cat > ${stateDir}/attic/config.toml <<TOML
default-server = "local"

[servers.local]
endpoint = "${cfg.endpoint}"
token = "$TOKEN"
TOML
        export XDG_CONFIG_HOME="${stateDir}"
        exec ${attic} watch-store ${cfg.cacheName}
      '';
    };
  };
}
