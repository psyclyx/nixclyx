{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.roles.base;
in

{
  options = {
    psyclyx.roles.base = {
      enable = mkEnableOption "role for baseline config, likely applicable to all hosts";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.ack
      pkgs.aria2
      pkgs.bat
      pkgs.btar
      pkgs.btop
      pkgs.bzip2
      pkgs.coreutils
      pkgs.curl
      pkgs.duf
      pkgs.eza
      pkgs.fd
      pkgs.file
      pkgs.findutils
      pkgs.fzf
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gzip
      pkgs.iotop
      pkgs.less
      pkgs.lsof
      pkgs.magic-wormhole
      pkgs.mc
      pkgs.moreutils
      pkgs.ncdu
      pkgs.nmon
      pkgs.p7zip
      pkgs.parallel
      pkgs.psmisc
      pkgs.pv
      pkgs.rar
      pkgs.rclone
      pkgs.reptyr
      pkgs.ripgrep
      pkgs.rsync
      pkgs.screen
      pkgs.silver-searcher
      pkgs.tmux
      pkgs.tree
      pkgs.unrar
      pkgs.unzip
      pkgs.util-linux
      pkgs.wget
      pkgs.xz
      pkgs.zip
      pkgs.zstd
    ];

    psyclyx = {
      programs = {
        zsh.enable = mkDefault true;
      };

      system = {
        containers.enable = mkDefault true;
        documentation.enable = mkDefault true;
        home-manager.enable = mkDefault true;
        locale.enable = mkDefault true;
        nix.enable = mkDefault true;
        nixpkgs.enable = mkDefault true;
        timezone.enable = mkDefault true;
      };
    };
  };
}
