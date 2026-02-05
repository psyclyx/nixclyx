{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "programs" "ssacli"];
  description = "HPE Smart Storage Array Command Line Interface";
  config = _: {
    boot.kernelModules = ["sg"];
    environment.systemPackages = [pkgs.psyclyx.ssacli];
  };
} args
