pkgs:
pkgs.buildEnv {
  name = "env-3DPrinting";
  paths = [
    pkgs.orca-slicer
  ];
  meta.description = "3D printing and CAD software";
}
