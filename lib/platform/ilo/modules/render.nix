# iLO platform — desired state + actions as compositions of the `ilo` tool.
#
# The tool owns Redfish and credentials; these hand it the target (the
# device's BMC address by default, overridable) and the desired state.
{ config, lib, pkgs, platformTool, ... }:
let
  i = config.ilo;
  specFile = pkgs.writeText "ilo-${i.address}.json" (builtins.toJSON i.spec);
in {
  system.build = {
    json = specFile;
    plan = pkgs.writeShellApplication {
      name = "ilo-plan";
      runtimeInputs = [ platformTool ];
      text = ''
        exec ilo "''${1:-${i.address}}" plan < ${specFile}
      '';
    };
    apply = pkgs.writeShellApplication {
      name = "ilo-apply";
      runtimeInputs = [ platformTool ];
      text = ''
        exec ilo "''${1:-${i.address}}" apply < ${specFile}
      '';
    };
    power = pkgs.writeShellApplication {
      name = "ilo-power";
      runtimeInputs = [ platformTool ];
      text = ''
        exec ilo "''${1:-${i.address}}" power "''${2:-status}"
      '';
    };
    info = pkgs.writeShellApplication {
      name = "ilo-info";
      runtimeInputs = [ platformTool ];
      text = ''
        exec ilo "''${1:-${i.address}}" info
      '';
    };
  };
}
