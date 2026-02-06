{
  lib,
  stdenv,
  babashka,
  makeWrapper,
  psyclyx,
  openssh,
  git,
  wireguard-tools,
}:
stdenv.mkDerivation {
  pname = "pki";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  buildInputs = [
    babashka
    psyclyx.ensure-key
    psyclyx.sign-key
    openssh
    git
    wireguard-tools
  ];

  installPhase = ''
    mkdir -p $out/share/pki $out/bin

    cp -r src bb.edn $out/share/pki/

    makeWrapper ${babashka}/bin/bb $out/bin/pki \
      --prefix PATH : ${lib.makeBinPath [
        psyclyx.ensure-key
        psyclyx.sign-key
        openssh
        git
        wireguard-tools
      ]} \
      --add-flags "-cp $out/share/pki/src" \
      --add-flags "-m pki.cli"
  '';

  meta = {
    description = "PKI management tool for SSH certificates and WireGuard";
    mainProgram = "pki";
  };
}
