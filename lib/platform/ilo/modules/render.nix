# iLO platform — desired state → spec JSON and BMC action scripts.
#
# Credentials come from the environment (ILO_USER / ILO_PASSWORD), never
# baked into an artifact: the caller decides where secrets live.
{ config, lib, pkgs, iloLib, ... }:
let
  i = config.ilo;
  specFile = pkgs.writeText "ilo-${i.address}.json" (builtins.toJSON i.spec);
  rf = sub: ''redfishtool -r "${i.address}" -u "$ILO_USER" -p "$ILO_PASSWORD" -S Always ${sub}'';
in {
  system.build = {
    json = specFile;
    plan = pkgs.writeShellApplication {
      name = "ilo-plan";
      runtimeInputs = [ iloLib.render ];
      text = ''ilo-config apply --dry-run "${i.address}" < ${specFile}'';
    };
    apply = pkgs.writeShellApplication {
      name = "ilo-apply";
      runtimeInputs = [ iloLib.render ];
      text = ''ilo-config apply "${i.address}" < ${specFile}'';
    };
    power = pkgs.writeShellApplication {
      name = "ilo-power";
      runtimeInputs = [ pkgs.redfishtool ];
      text = ''
        action="''${1:-}"
        case "$action" in
          on)    ${rf "Systems -F reset On"} ;;
          off)   ${rf "Systems -F reset ForceOff"} ;;
          reset) ${rf "Systems -F reset ForceRestart"} ;;
          "")    ${rf "Systems -F get"} ;;
          *)     echo "Unknown power action: $action" >&2; exit 1 ;;
        esac
      '';
    };
    info = pkgs.writeShellApplication {
      name = "ilo-info";
      runtimeInputs = [ pkgs.redfishtool ];
      text = rf "Systems -F get";
    };
  };
}
