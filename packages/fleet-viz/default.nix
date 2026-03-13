{ pkgs, fleetData }:
let
  fleetJson = pkgs.writeText "fleet.json" (builtins.toJSON fleetData);
in
pkgs.runCommand "fleet-viz" {
  nativeBuildInputs = [ pkgs.python3 pkgs.graphviz ];
} ''
  mkdir -p $out
  cp ${fleetJson} $out/fleet.json
  ${pkgs.python3}/bin/python3 ${./generate.py} ${fleetJson} $out
''
