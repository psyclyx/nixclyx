{
  colmena,
  nixclyx,
  nixpkgs,
  inputs,
  ...
}:
colmena.lib.makeHive {
  meta = {
    nixpkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ nixclyx.overlays.default ];
    };
    specialArgs = { inherit inputs; };
  };

  lab-1 =
    { ... }:
    {
      imports = [ ./configs/nixos/lab/lab-1.nix ];
      deployment = {
        targetHost = "lab-1.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-2 =
    { ... }:
    {
      imports = [ ./configs/nixos/lab/lab-2.nix ];
      deployment = {
        targetHost = "lab-2.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-3 =
    { ... }:
    {
      imports = [ ./configs/nixos/lab/lab-3.nix ];
      deployment = {
        targetHost = "lab-3.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };

  lab-4 =
    { ... }:
    {
      imports = [ ./configs/nixos/lab/lab-4.nix ];
      deployment = {
        targetHost = "lab-4.home.psyclyx.net";
        targetPort = 22;
        targetUser = "root";
      };
    };
}
