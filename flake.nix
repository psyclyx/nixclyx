{
  description = "nixos/nix-darwin configurations";

  inputs = {
    nixpkgs.url = "github:psyclyx/nixpkgs/psyclyx";
    psyclyx-emacs = {
      url = "github:psyclyx/emacs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      url = "github:psyclyx/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
    zsh-pure = {
      url = "github:sindresorhus/pure";
      flake = false;
    };
  };

  outputs = inputs: import ./outputs.nix inputs;
}
