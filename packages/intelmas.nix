{
  lib,
  fetchzip,
  stdenv,
  rpmextract,
  autoPatchelfHook,
}:
let
  version = "2.5.0-0";
  hash = "sha256-gveRM8JPp9NlrKtm94Ktd1/PAuWU/b43SkPdpOJOi8I=";
in
stdenv.mkDerivation {
  pname = "intelmas";
  inherit version;

  src = fetchzip {
    stripRoot = false;
    inherit hash;
    url = "https://downloadmirror.intel.com/822151/Intel_MAS_CLI_Tool_Linux_2.5.zip";
  };

  buildInputs = [ stdenv.cc.cc.lib ];

  nativeBuildInputs = [
    autoPatchelfHook
    rpmextract
  ];

  unpackPhase = ''
    runHook preUnpack
    ls
    rpmextract $src/intelmas-${version}.x86_64.rpm

    runHook postUnpack
  '';

  dontConfigure = true;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/intelmas

    cp -rv ./usr/bin $out
    cp -rv ./usr/lib/intelmas $out/lib/intelmas

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
