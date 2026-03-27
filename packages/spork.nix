{ lib, stdenv, fetchFromGitHub, janet, jpm }:

stdenv.mkDerivation rec {
  pname = "spork";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "janet-lang";
    repo = "spork";
    rev = "v${version}";
    hash = "sha256-FFBX1gcPLvgGZXAtIkN3C0vYhcKsWwsjv7n6+oRSbbA=";
  };

  nativeBuildInputs = [ janet jpm ];

  postPatch = ''
    export JANET_MODPATH="$out/lib/janet"
    export JANET_BINPATH="$out/bin"
    export JANET_MANPATH="$out/share/man"
    export JANET_HEADERPATH="${janet}/include/janet"
    export JANET_LIBPATH="${janet}/lib"
  '';

  buildPhase = ''
    runHook preBuild
    jpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/janet $out/share/man/man1
    jpm install
    runHook postInstall
  '';

  meta = with lib; {
    description = "Janet's official utility library and CLI tools";
    homepage = "https://github.com/janet-lang/spork";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
