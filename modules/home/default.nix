{
  name,
  email,
  modules,
  ...
}:
{
  home.stateVersion = "25.05";
  fonts.fontconfig.enable = true;

  imports = [
    ./config.nix
    { psyclyx.user = { inherit name email; }; }
  ] ++ modules;
}
