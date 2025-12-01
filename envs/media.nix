pkgs:
pkgs.buildEnv {
  name = "env-media";
  paths = [
    pkgs.ffmpeg
    pkgs.imagemagick
    pkgs.mpv
    pkgs.vlc
  ];
  meta.description = "Media playback and processing tools";
}
