let
  nixos = ./nixos;
  config = ./config;
  default = {
    imports = [
      nixos
      config
    ];
  };
in
{
  inherit config default nixos;
}
