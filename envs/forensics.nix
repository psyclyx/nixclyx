pkgs:
pkgs.buildEnv {
  name = "env-forensics";
  paths = [
    pkgs.hashcat
    pkgs.john
    pkgs.libxcrypt
    pkgs.sleuthkit
    pkgs.wordlists
  ];
  meta.description = "Digital forensics and security tools";
}
