pkgs:
pkgs.buildEnv {
  name = "env-3dprinting";
  paths = [
    pkgs.freecad-wayland
    pkgs.orca-slicer
  ];
  meta.description = "3D printing and CAD software";
}
