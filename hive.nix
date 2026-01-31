let
  nixclyx = import ./.;
  module = nixclyx.nixosModules.default;
in
{
  meta = {
    nixpkgs = import nixclyx.passthrough.nixpkgs {
      system = "x86_64-linux";
      overlays = [ nixclyx.overlays.default ];
    };
  };

  sigil =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/sigil
      ];
      deployment = {
        allowLocalDeployment = true;
        targetHost = "sigil.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  vigil =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/vigil
      ];
      deployment = {
        targetHost = "vigil.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-1 =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/lab/lab-1.nix
      ];
      deployment = {
        targetHost = "lab-1.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-2 =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/lab/lab-2.nix
      ];
      deployment = {
        targetHost = "lab-2.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-3 =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/lab/lab-3.nix
      ];
      deployment = {
        targetHost = "lab-3.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-4 =
    { ... }:
    {
      imports = [
        module
        ./configs/nixos/lab/lab-4.nix
      ];
      deployment = {
        targetHost = "lab-4.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };
}
