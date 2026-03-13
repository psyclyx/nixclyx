{
  path = ["psyclyx" "nixos" "hardware" "ipmi" "ilo"];
  description = "HPE Integrated Lights Out";
  config = {pkgs, ...}: {
    boot.initrd.availableKernelModules = ["hpilo"];
    environment.systemPackages = [
      pkgs.redfishtool
      pkgs.psyclyx.ilo
      pkgs.psyclyx.ilo4-console
    ];
  };
}
