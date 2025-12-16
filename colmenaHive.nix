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
