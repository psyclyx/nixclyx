{
  path = ["psyclyx" "nixos" "programs" "orca-slicer"];
  description = "OrcaSlicer 3D-printing slicer";
  config = {pkgs, ...}: {
    environment.systemPackages = [pkgs.orca-slicer];
    psyclyx.nixos.system.locale.extraSupported = ["en_GB.UTF-8"];
  };
}
