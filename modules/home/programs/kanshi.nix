{
  path = ["psyclyx" "home" "programs" "kanshi"];
  description = "kanshi dynamic output configuration";
  config = {
    config,
    lib,
    ...
  }: let
    monitors = config.psyclyx.home.hardware.monitors;

    mkMode = mode:
      "${toString mode.width}x${toString mode.height}"
      + lib.optionalString (mode.refresh != null) "@${toString mode.refresh}Hz";

    # Translate a declared monitor into a kanshi output directive. Only
    # enabled outputs carry geometry; disabled ones are just switched
    # off.
    #
    # kanshi matches criteria against "<make> <model> <serial>" via
    # fnmatch (substituting the literal "Unknown" for any absent field,
    # e.g. a display with no serial). Our identifiers are description
    # prefixes, so a trailing glob turns the criteria into a prefix
    # match — the fnmatch equivalent of the old wlr-randr startswith
    # logic — which also absorbs the "Unknown" serial slot.
    mkOutput = _: m:
      {
        criteria = "${m.identifier}*";
        status =
          if m.enable
          then "enable"
          else "disable";
      }
      // lib.optionalAttrs m.enable {
        mode =
          if m.mode == null
          then null
          else mkMode m.mode;
        position = "${toString m.position.x},${toString m.position.y}";
        scale =
          if m.scale == 1.0
          then null
          else 1.0 * m.scale;
      };
  in {
    services.kanshi = {
      enable = true;
      systemdTarget = "graphical-session.target";
      settings = [
        {
          profile.name = "default";
          profile.outputs = lib.mapAttrsToList mkOutput monitors;
        }
      ];
    };
  };
}
