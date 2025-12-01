pkgs:
pkgs.buildEnv {
  name = "env-network";
  paths = [
    pkgs.rsync
    pkgs.aria2
    pkgs.rclone
    pkgs.magic-wormhole
  ];
  meta.description = "Advanced network transfer utilities";
}
