{
  lib,
  stdenv,
  fetchzip,
  makeWrapper,
}:
let
  version = "120-stable_2024-12-18";
  archMap = {
    "aarch64-darwin" = "Darwin-arm64";
  };
  getBinary =
    system:
    let
      arch = archMap.${system} or (throw "Unsupported system: ${system} ");
    in
    fetchzip {
      url = "https://files.pharo.org/get-files/120/pharo-vm-${arch}-stable.zip";
      sha256 = { "Darwin-arm64" = "sha256-IsynTLOySc6NXjeslLxIW9PfipTZXpHsbVzWCcfTz0k="; }.${arch};
    };
in
stdenv.mkDerivation {
  pname = "pharo12-stable";
  inherit version;
  src = getBinary stdenv.hostPlatform.system;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r $src $out/Applications/Pharo.app
    makeWrapper $out/Applications/Pharo.app/Contents/MacOS/Pharo $out/bin/pharo

    runHook postInstall
  '';

  meta = {
    description = "Clean and innovative Smalltalk-inspired environment";
    homepage = "https://pharo.org";
    changelog = "https://github.com/pharo-project/pharo/releases/";
    license = lib.licenses.mit;
    longDescription = ''
      Pharo's goal is to deliver a clean, innovative, free open-source
      Smalltalk-inspired environment. By providing a stable and small core
      system, excellent dev tools, and maintained releases, Pharo is an
      attractive platform to build and deploy mission critical applications.
    '';
  };
}
