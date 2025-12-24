let
  psyclyxModules = import ./psyclyx;
  psyclyxHome = psyclyxModules.home;
  psyclyx = psyclyxModules.default;
in
rec {
  "psyclyx/home" = psyclyxHome;
  inherit psyclyx;
}
