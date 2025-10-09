let
  mkLab =
    {
      modules ? [ ],
    }:
    {
      system = "x86_64-linux";
      modules = [ ./common.nix ] ++ modules;
    };
in
{
  lab-1 = mkLab { modules = [ ./lab-1.nix ]; };
  lab-2 = mkLab { modules = [ ./lab-2.nix ]; };
}
