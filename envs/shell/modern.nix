pkgs:
pkgs.buildEnv {
  name = "env-modern";
  paths = [
    pkgs.ripgrep
    pkgs.fd
    pkgs.fzf

    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.pv

    pkgs.duf
    pkgs.ncdu

    pkgs.lazygit
    pkgs.yazi
  ];
  meta.description = "Modern CLI experience - ripgrep, fd, fzf, bat, eza, and other quality-of-life improvements";
}
