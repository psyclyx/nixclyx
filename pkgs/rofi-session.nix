{sway, swaylock, writeShellApplication}:
writeShellApplication {
  name = "rofi-sway-session";
  runtimeInputs = [sway swaylock];
  text = ''
    if [ "$#" -eq 0 ]; then
      echo "Lock"
      echo "Logout"
    else
      case "$1" in
        "Lock") swaylock ;;
        "Logout") swaymsg exit ;;
      esac
    fi
  '';
}
