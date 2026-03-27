{ lib, stdenv, fetchFromGitHub, janet, jpm, spork }:

let
  jayson-src = fetchFromGitHub {
    owner = "CFiggers";
    repo = "jayson";
    rev = "4f54041617340c8ff99bc1e6b285b720184965e2";
    hash = "sha256-961JRjy/JB0mDGTVbMofBf6vwu95TcUnnb7GxYkQ9EI=";
  };
  cmd-src = fetchFromGitHub {
    owner = "CFiggers";
    repo = "cmd";
    rev = "b0a34d6e854578bd672d43303e80b9777af08b42";
    hash = "sha256-Kkwde3hHgbi8aj9ud6rOh13KWVxdNCNY4zXnDVj7uzA=";
  };
  judge-src = fetchFromGitHub {
    owner = "CFiggers";
    repo = "judge";
    rev = "1d329cb3a7384c3ff0f6232e60d81aa9db3a5440";
    hash = "sha256-iR7bCEVvJK3lF9m4hXJhQ4JRnhvcGjgBrWuWIiYT7dg=";
  };
in
stdenv.mkDerivation rec {
  pname = "janet-lsp";
  version = "unstable-2026-03-27";

  src = fetchFromGitHub {
    owner = "CFiggers";
    repo = "janet-lsp";
    rev = "e31cd7f78608c2516aa43532888b040c2a5900b1";
    hash = "sha256-OLY1G4YL1eFRltWQpBfmdRiHiPVvLEthWCPJchUUPj4=";
  };

  nativeBuildInputs = [ janet jpm ];

  # src/main.janet runs git rev-parse at load time for version info
  prePatch = ''
    sed -i '/^(def commit/,/^[[:space:]]*(if out/c\(def commit "${builtins.substring 0 7 src.rev}")' src/main.janet
  '';

  postPatch = ''
    export DEPS="$TMPDIR/janet-deps"
    mkdir -p $DEPS

    export JANET_HEADERPATH="${janet}/include/janet"
    export JANET_LIBPATH="${janet}/lib"

    # Install spork modules into dep tree
    cp -r ${spork}/lib/janet/* $DEPS/

    # Build and install jayson into dep tree
    export JANET_MODPATH="$DEPS"
    export JANET_BINPATH="$TMPDIR/bin"
    mkdir -p $JANET_BINPATH

    pushd $(mktemp -d)
    cp -r ${jayson-src}/* .
    chmod -R u+w .
    jpm build && jpm install
    popd

    # Build and install cmd into dep tree
    pushd $(mktemp -d)
    cp -r ${cmd-src}/* .
    chmod -R u+w .
    jpm build && jpm install
    popd

    # Build and install judge into dep tree
    pushd $(mktemp -d)
    cp -r ${judge-src}/* .
    chmod -R u+w .
    jpm build && jpm install
    popd

    export JANET_PATH="$DEPS"
  '';

  buildPhase = ''
    runHook preBuild
    export JANET_MODPATH="$DEPS"
    jpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    export JANET_MODPATH="$out/lib/janet"
    export JANET_BINPATH="$out/bin"
    mkdir -p $out/bin $out/lib/janet
    jpm install
    runHook postInstall
  '';

  meta = with lib; {
    description = "A Language Server Protocol implementation for Janet";
    homepage = "https://github.com/CFiggers/janet-lsp";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
