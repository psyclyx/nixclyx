# SwOS platform — deploy/diff as no-magic compositions of the `swos` tool.
#
# The tool owns the connection and the protocol; these only supply the
# desired config (the platform's own JSON) and name the target, exactly
# as you would if you ran `swos` yourself.
{ config, lib, pkgs, platformTool, ... }:
let
  jsonFile = config.system.build.json;
in {
  system.build = {
    diff = pkgs.writeShellApplication {
      name = "swos-diff";
      runtimeInputs = [ platformTool ];
      text = ''
        [ $# -ge 1 ] || { echo "usage: swos-diff <target>" >&2; exit 2; }
        exec swos "$1" diff < ${jsonFile}
      '';
    };
    deploy = pkgs.writeShellApplication {
      name = "swos-deploy";
      runtimeInputs = [ platformTool ];
      text = ''
        [ $# -ge 1 ] || { echo "usage: swos-deploy <target>" >&2; exit 2; }
        exec swos "$1" push < ${jsonFile}
      '';
    };
  };
}
