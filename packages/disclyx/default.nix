{
  writeShellApplication,
  coreutils,
  util-linux,
  gptfdisk,
  bcachefs-tools,
  dosfstools,
}:
writeShellApplication {
  name = "disclyx";
  runtimeInputs = [
    coreutils
    util-linux
    gptfdisk
    bcachefs-tools
    dosfstools
  ];
  text = builtins.readFile ./disclyx.bash;
}
