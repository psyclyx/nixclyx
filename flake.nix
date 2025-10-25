{
  description = "nixos/nix-darwin configurations";

  inputs = {
    nixpkgs.url = "github:psyclyx/nixpkgs/psyclyx";
    psyclyx-emacs.url = "git+file:submodules/emacs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: import ./outputs.nix inputs;
}
