# Supported platforms
rec {
  aarch64-darwin = [ "aarch64-darwin" ];
  aarch64-linux = [ "aarch64-linux" ];
  x86_64-darwin = [ "x86_64-darwin" ];
  x86_64-linux = [ "x86_64-linux" ];

  aarch64 = [
    aarch64-linux
    aarch64-darwin
  ];

  x86_64 = [
    x86_64-linux
    x86_64-darwin
  ];

  darwin = [
    x86_64-darwin
    aarch64-darwin
  ];

  linux = [
    x86_64-linux
    aarch64-linux
  ];

  all = [
    x86_64-linux
    x86_64-darwin
    aarch64-linux
    aarch64-darwin
  ];
}
