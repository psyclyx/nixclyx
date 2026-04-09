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
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "iLO hostname for Redfish API. Null = derive from entity name + host site.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Server hardware model.";
    };
    mgmtNetwork = lib.mkOption {
      type = lib.types.str;
      default = "mgmt";
      description = "Network entity for deriving the management zone domain.";
    };
  };

  attrs = name: entity: top: let
    ilo = entity.ilo;
    # Derive hostname from entity name + mgmt zone domain if not explicit.
    mgmtNet = top.entities.${ilo.mgmtNetwork} or null;
    zoneName = if mgmtNet != null then mgmtNet.attrs.zoneName or null else null;
    derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
    resolvedHostname = if ilo.hostname != null then ilo.hostname else derivedHostname;
  in {
    address = resolvedHostname;
    label = if ilo.model != "" then ilo.model else name;
  };

  verbs = name: entity: top: let
    host = (egregorLib.mkType {}).attrs name entity top; # can't self-reference attrs easily
    # Resolve hostname the same way as attrs
    ilo = entity.ilo;
    mgmtNet = top.entities.${ilo.mgmtNetwork} or null;
    zoneName = if mgmtNet != null then mgmtNet.attrs.zoneName or null else null;
    derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
    resolvedHostname = if ilo.hostname != null then ilo.hostname else derivedHostname;
  in {
    power = {
      description = "Server power control (on|off|reset, or show state).";
      impl = ''
        action="''${1:-}"
        case "$action" in
          on)    ${rf resolvedHostname "Systems -F reset On"} ;;
          off)   ${rf resolvedHostname "Systems -F reset ForceOff"} ;;
          reset) ${rf resolvedHostname "Systems -F reset ForceRestart"} ;;
          "")    ${rf resolvedHostname "Systems -F get"} ;;
          *)     echo "Unknown power action: $action" >&2; exit 1 ;;
        esac
      '';
    };
    info = {
      description = "Show system information.";
      impl = rf resolvedHostname "Systems -F get";
    };
  };
}
