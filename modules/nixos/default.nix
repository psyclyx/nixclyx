let
  psyclyxModules = import ./psyclyx;
in
{
  "psyclyx/config" = psyclyxModules.config;
  "psyclyx/nixos" = psyclyxModules.nixos;
  psyclyx = psyclyxModules.default;
}
