# Entity type: HPE iLO BMC.
{ lib, egregorLib, config, ... }:
let
  rf = hostname: args:
    ''redfishtool -r "${hostname}" -u "$ILO_USER" -p "$ILO_PASSWORD" -S Always ${args}'';
in
egregorLib.mkType {
  name = "ilo";
  topConfig = config;
  description = "HPE Integrated Lights-Out baseboard management controller.";

  options = {
    hostname = lib.mkOption {
      type = lib.types.str;
      description = "iLO hostname or IP for Redfish API access.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Server hardware model.";
    };
  };

  attrs = _name: entity: _top: {
    address = entity.ilo.hostname;
    label =
      if entity.ilo.model != ""
      then "${entity.ilo.model}"
      else entity.attrs.name;
  };

  verbs = _name: entity: _top: let
    host = entity.ilo.hostname;
  in {
    power = {
      description = "Server power control (on|off|reset, or show state).";
      impl = ''
        action="''${1:-}"
        case "$action" in
          on)    ${rf host "Systems -F reset On"} ;;
          off)   ${rf host "Systems -F reset ForceOff"} ;;
          reset) ${rf host "Systems -F reset ForceRestart"} ;;
          "")    ${rf host "Systems -F get"} ;;
          *)     echo "Unknown power action: $action" >&2; exit 1 ;;
        esac
      '';
    };
    info = {
      description = "Show system information.";
      impl = rf host "Systems -F get";
    };
  };
}
