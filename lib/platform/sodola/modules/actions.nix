# Sodola platform — deploy as a no-magic composition of the `sodola` tool.
{ config, lib, pkgs, platformTool, ... }:
let
  jsonFile = config.system.build.json;
in {
  system.build.deploy = pkgs.writeShellApplication {
    name = "sodola-deploy";
    runtimeInputs = [ platformTool ];
    text = ''
      [ $# -ge 1 ] || { echo "usage: sodola-deploy <target>" >&2; exit 2; }
      exec sodola "$1" push < ${jsonFile}
    '';
  };
}
