{ ... }:
{
  config = {
    # Nonstandard `enable` behavior:
    # Module targets a specific stateVersion, so an option to disable this isn't useful.
    home.stateVersion = "25.05";
  };
}
