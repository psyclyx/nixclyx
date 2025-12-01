pkgs:
pkgs.buildEnv {
  name = "env-modern";
  paths = [
    # Modern search
    pkgs.ripgrep
    pkgs.fd
    pkgs.fzf

    # Enhanced file viewing
    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.pv

    # Disk utilities
    pkgs.duf
    pkgs.ncdu

    # File manager
    pkgs.yazi
  ];
  meta.description = "Modern CLI experience - ripgrep, fd, fzf, bat, eza, and other quality-of-life improvements";
}
