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
    power-status = {
      description = "Check server power state.";
      impl = rf host "Systems -F get";
    };
    power-on = {
      description = "Power on server.";
      impl = rf host "Systems -F reset On";
    };
    power-off = {
      description = "Force power off.";
      impl = rf host "Systems -F reset ForceOff";
    };
    power-reset = {
      description = "Force restart.";
      impl = rf host "Systems -F reset ForceRestart";
    };
    info = {
      description = "Show system information.";
      impl = rf host "Systems -F get";
    };
  };
}
