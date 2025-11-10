pkgs:
pkgs.buildEnv {
  name = "shell-utils";
  paths = [
    pkgs.coreutils
    pkgs.util-linux
    pkgs.file
    pkgs.less
    pkgs.moreutils
    pkgs.parallel
    pkgs.pv
    pkgs.tree

    pkgs.findutils
    pkgs.ack
    pkgs.bat
    pkgs.duf
    pkgs.eza
    pkgs.fd
    pkgs.fzf
    pkgs.mc
    pkgs.ncdu
    pkgs.ripgrep
    pkgs.silver-searcher
    pkgs.sleuthkit

    pkgs.reptyr
    pkgs.screen
    pkgs.tmux

    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused

    pkgs.aria2
    pkgs.curl
    pkgs.magic-wormhole
    pkgs.rclone
    pkgs.rsync
    pkgs.wget

    pkgs.bzip2
    pkgs.gzip
    pkgs.p7zip
    pkgs.rar
    pkgs.tar
    pkgs.unrar
    pkgs.unzip
    pkgs.xz
    pkgs.zip
    pkgs.zstd

    pkgs.btop
    pkgs.iotop
    pkgs.lsof
    pkgs.nmon
    pkgs.psmisc
  ];
}
