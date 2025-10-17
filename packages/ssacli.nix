{
  lib,
  fetchurl,
  stdenv,
  rpmextract,
  autoPatchelfHook,
}:
let
  version = "5.10-44.0";
  hash = "sha256-hX5eBgrwMH7p0EStwgh/yg1Rf4dsvuLMInfAov8l2EQ=";
in
stdenv.mkDerivation {
  pname = "ssacli";
  inherit version;

  src = fetchurl {
    inherit hash;
    url = "https://downloads.linux.hpe.com/sdr/repo/mcp/centos/7/x86_64/current/ssacli-${version}.x86_64.rpm";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    rpmextract
  ];

  unpackPhase = ''
    runHook preUnpack

    rpmextract $src

    runHook postUnpack
  '';

  dontConfigure = true;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # executables
    mkdir -pv $out/bin
    cp -v ./opt/smartstorageadmin/ssacli/bin/mklocks.sh $out/bin/mklocks.sh
    cp -v ./opt/smartstorageadmin/ssacli/bin/rmstr $out/bin/rmstr
    cp -v ./opt/smartstorageadmin/ssacli/bin/ssacli $out/bin/ssacli
    cp -v ./opt/smartstorageadmin/ssacli/bin/ssascripting $out/bin/ssascripting

    # man pages
    mkdir -pv $out/share
    cp -rv ./usr/man $out/share

    runHook postInstall
  '';

  meta =
    let
      inherit (lib) sourceTypes licenses maintainers;
    in
    {
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      maintainers = [ maintainers.psyclyx ];
    };
}
