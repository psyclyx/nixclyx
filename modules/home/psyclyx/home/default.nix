{ ... }:
{
  imports = [
    ./hardware
    ./programs
    ./roles
    ./services
    ./system
    ./info.nix
  ];

  config = {
    home.stateVersion = "25.11";
  };
}
