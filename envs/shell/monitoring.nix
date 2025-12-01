pkgs:
pkgs.buildEnv {
  name = "env-monitoring";
  paths = [
    pkgs.btop
    pkgs.lsof
    pkgs.iotop
    pkgs.psmisc
  ];
  meta.description = "System monitoring and process management";
}
