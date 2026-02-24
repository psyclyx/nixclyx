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
    lib,
    pkgs,
    ...
  }: let
    domain = builtins.head (builtins.match "https?://([^/:]+).*" cfg.url);
    kioskSession = pkgs.writeShellScript "kiosk-session" ''
      ${pkgs.wlr-randr}/bin/wlr-randr | ${pkgs.gawk}/bin/awk '/^[^ ]/{print $1}' | while read -r output; do
        ${pkgs.wlr-randr}/bin/wlr-randr --output "$output" --scale 2
      done
      rm -rf /var/lib/${cfg.user}/.config/mozilla /var/lib/${cfg.user}/.cache/mozilla
      ${pkgs.firefox}/bin/firefox --kiosk ${cfg.url} &
      PID=$!
      trap 'kill $PID 2>/dev/null' EXIT TERM INT HUP
      wait $PID
    '';
    cageCmd = "${pkgs.cage}/bin/cage -s -- ${kioskSession}";
  in {
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      home = "/var/lib/${cfg.user}";
      createHome = true;
    };
    users.groups.${cfg.user} = {};

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = cageCmd;
          user = cfg.user;
        };
        initial_session = {
          command = cageCmd;
          user = cfg.user;
        };
      };
    };

    environment.variables.WLR_LIBINPUT_NO_DEVICES = "1";

    systemd.services.greetd.serviceConfig = {
      Restart = "always";
      RestartSec = "3";
      KillMode = "control-group";
      TimeoutStopSec = lib.mkForce 10;
    };
  };
}
