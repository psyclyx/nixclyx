pkgs:
pkgs.buildEnv {
  name = "env-core";
  paths = [
    # Essential POSIX utilities
    pkgs.coreutils
    pkgs.util-linux
    pkgs.file
    pkgs.less
    pkgs.findutils
    pkgs.gnugrep

    # Text processing
    pkgs.gawk
    pkgs.gnused
    pkgs.moreutils
    pkgs.parallel

    # Basic compression
    pkgs.btar
    pkgs.gzip
    pkgs.bzip2
    pkgs.xz

    # Basic network
    pkgs.curl
    pkgs.wget

    # Editor and VCS
    pkgs.vim
    pkgs.git

    # General utilities
    pkgs.sleuthkit
  ];
  meta.description = "Core shell utilities - essential POSIX tools, text processing, basic compression/network, editor, and VCS";
}
