{
  lib,
  stdenv,
  callPackage,
  fetchurl,
  libGL,
  libx11,
  libevdev,
  libinput,
  libxkbcommon,
  pixman,
  pkg-config,
  scdoc,
  udev,
  wayland,
  wayland-protocols,
  wayland-scanner,
  xwayland,
  zig_0_15,
  wlroots_0_19,
  withManpages ? true,
  xwaylandSupport ? true,
}:

let
  sources = import ../../npins;

  # River 0.4-dev requires xkb_keymap_get_as_string2, added in xkbcommon 1.12.0.
  # Nixpkgs has 1.11.0, so override to 1.13.1.
  libxkbcommon' = libxkbcommon.overrideAttrs (old: rec {
    version = "1.13.1";
    src = fetchurl {
      url = "https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-${version}.tar.gz";
      hash = "sha256-rrlRlkwvfswIF0y1UXli0VdZXp4/OPxKEwuR3C+f7Bg=";
    };
    patches = [];
    doCheck = false;
  });
in
stdenv.mkDerivation (finalAttrs: {
  pname = "river";
  version = "0.4.0-dev";

  src = sources.river;

  deps = callPackage ./build.zig.zon.nix {};

  nativeBuildInputs =
    [
      pkg-config
      wayland-scanner
      xwayland
      zig_0_15
    ]
    ++ lib.optional withManpages scdoc;

  buildInputs =
    [
      libGL
      libevdev
      libinput
      libxkbcommon'
      pixman
      udev
      wayland
      wayland-protocols
      wlroots_0_19
    ]
    ++ lib.optional xwaylandSupport libx11;

  zigBuildFlags =
    [
      "--system"
      "${finalAttrs.deps}"
    ]
    ++ lib.optional withManpages "-Dman-pages"
    ++ lib.optional xwaylandSupport "-Dxwayland";

  postInstall = ''
    install contrib/river.desktop -Dt $out/share/wayland-sessions
  '';

  meta = {
    homepage = "https://codeberg.org/river/river";
    description = "Dynamic tiling Wayland compositor (0.4.0-dev)";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "river";
  };
})
