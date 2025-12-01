pkgs:
pkgs.buildEnv {
  name = "env-compression";
  paths = [
    pkgs.zstd
    pkgs.zip
    pkgs.unzip
    pkgs.p7zip
    pkgs.rar
    pkgs.unrar
  ];
  meta.description = "Additional compression formats beyond basic tar/gzip/xz";
}
