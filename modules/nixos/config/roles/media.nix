{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.media;
in

{
  options = {
    psyclyx.roles.media = {
      enable = lib.mkEnableOption "role for hosts that need to play/work with media";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      ffmpeg
      imagemagick
      mpv
      vlc
    ];
  };
}
