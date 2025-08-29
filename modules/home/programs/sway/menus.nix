{
  config,
  pkgs,
  lib,
}:
let
  # Assume these are on path
  fuzzel = "fuzzel";
  grim = "grim";
  makoctl = "makoctl";
  slurp = "slurp";
  wl-copy = "wl-copy";
  swaymsg = "swaymsg";
  swaylock = "swaylock";
  jq = lib.getExe pkgs.jq;
in
{
  power-menu = pkgs.writeShellScriptBin "power-menu" ''
    options="Lock\nLogout\nSuspend\nReboot\nShutdown"
    chosen=$(echo -e "$options" | ${fuzzel} \
      --dmenu \
      --prompt "Power: " )

    case $chosen in
      "Lock")
        ${swaylock}
        ;;
      "Logout")
        loginctl terminate-session $XDG_SESSION_ID
        ;;
      "Suspend")
        systemctl suspend
        ;;
      "Shutdown")
        systemctl poweroff
        ;;
      "Reboot")
        systemctl reboot
        ;;
    esac
  '';

  screenshot-menu = pkgs.writeShellScriptBin "screenshot-menu" ''
    options="Full Screen\nSelection\nCurrent Window\nFull Screen (Clipboard)\nSelection (Clipboard)\nCurrent Window (Clipboard)"
    chosen=$(echo -e "$options" | ${fuzzel} \
      --dmenu \
      --prompt "Screenshot: " )

    screenshot_dir="''${XDG_PICTURES_DIR}/screenshots"
    mkdir -p "$screenshot_dir"
    filename="$screenshot_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

    case $chosen in
      "Full Screen")
        ${grim} "$filename"
        ${makoctl} notify "Screenshot saved" "$filename"
        ;;
      "Selection")
        ${grim} -g "$(${slurp})" "$filename"
        if [ $? -eq 0 ]; then
          ${makoctl} notify "Screenshot saved" "$filename"
        fi
        ;;
      "Current Window")
        ${grim} -g "$(${swaymsg} -t get_tree | ${jq} -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" "$filename"
        ${makoctl} notify "Screenshot saved" "$filename"
        ;;
      "Full Screen (Clipboard)")
        ${grim} - | ${wl-copy} -t image/png
        ${makoctl} notify "Screenshot copied to clipboard"
        ;;
      "Selection (Clipboard)")
        ${grim} -g "$(${slurp})" - | ${wl-copy} -t image/png
        if [ $? -eq 0 ]; then
          ${makoctl} notify "Screenshot copied to clipboard"
        fi
        ;;
      "Current Window (Clipboard)")
        ${grim} -g "$(${swaymsg} -t get_tree | ${jq} -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | ${wl-copy} -t image/png
        ${makoctl} notify "Screenshot copied to clipboard"
        ;;
    esac
  '';
}
