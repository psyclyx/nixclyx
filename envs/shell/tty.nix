pkgs:
pkgs.buildEnv {
  name = "env-tty";
  paths = [
    pkgs.reptyr
    pkgs.dtach
    pkgs.screen
    pkgs.tmux
    pkgs.zellij
  ];
  meta.description = "Terminal multiplexers and TTY utilities";
}
