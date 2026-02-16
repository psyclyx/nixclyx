{
  path = ["psyclyx" "nixos" "services" "kiosk"];
  description = "Cage Wayland kiosk";
  options = {lib, ...}: {
    url = lib.mkOption {
      type = lib.types.str;
      description = "URL to display in the kiosk.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "kiosk";
      description = "User to autologin as.";
    };
  };
  config = {
    cfg,
    pkgs,
    ...
  }: let
    domain = builtins.head (builtins.match "https?://([^/:]+).*" cfg.url);
  in {
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      home = "/var/lib/${cfg.user}";
      createHome = true;
    };
    users.groups.${cfg.user} = {};

    services.cage = {
      enable = true;
      user = cfg.user;
      program = "${pkgs.firefox}/bin/firefox --kiosk ${cfg.url}";
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "kiosk-set-cookie" ''
        set -euo pipefail

        if [ $# -ne 2 ]; then
          echo "Usage: kiosk-set-cookie <name> <value>"
          exit 1
        fi

        COOKIE_NAME="$1"
        COOKIE_VALUE="$2"
        KIOSK_HOME="/var/lib/${cfg.user}"
        DOMAIN="${domain}"

        PROFILE_DIR=$(find "$KIOSK_HOME/.mozilla/firefox" -maxdepth 1 -name '*.default*' -type d | head -1)

        if [ -z "$PROFILE_DIR" ]; then
          echo "Error: Firefox profile not found under $KIOSK_HOME/.mozilla/firefox"
          echo "Start the kiosk at least once to create the profile."
          exit 1
        fi

        systemctl stop cage-tty1

        EXPIRY=$(( $(date +%s) + 86400 * 365 ))

        ${pkgs.sqlite}/bin/sqlite3 "$PROFILE_DIR/cookies.sqlite" \
          "DELETE FROM moz_cookies WHERE name = '$COOKIE_NAME' AND host = '.$DOMAIN';"
        ${pkgs.sqlite}/bin/sqlite3 "$PROFILE_DIR/cookies.sqlite" \
          "INSERT INTO moz_cookies (originAttributes, name, value, host, path, expiry, isSecure, isHttpOnly, sameSite, rawSameSite, schemeMap) VALUES ('''', '$COOKIE_NAME', '$COOKIE_VALUE', '.$DOMAIN', '/', $EXPIRY, 1, 1, 0, 0, 0);"

        systemctl start cage-tty1
        echo "Cookie '$COOKIE_NAME' set for .$DOMAIN. Cage session restarted."
      '')
    ];
  };
}
