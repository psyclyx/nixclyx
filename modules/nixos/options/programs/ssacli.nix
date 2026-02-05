{
  path = ["psyclyx" "nixos" "programs" "ssacli"];
  description = "HPE Smart Storage Array Command Line Interface";
  config = {pkgs, ...}: {
    boot.kernelModules = ["sg"];
    environment.systemPackages = [pkgs.psyclyx.ssacli];
  };
}
