let
  home = ./home;
  default = {
    imports = [ home ];
  };
in
{
  inherit home default;
}
