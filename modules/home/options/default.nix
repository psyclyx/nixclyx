{nixclyx}: let
  inherit (nixclyx) sources loadFlake;
in
  {...}: {
    imports = [
      (loadFlake sources.ags).homeManagerModules.ags
      "${sources.sops-nix}/modules/home-manager/sops.nix"
      ./hardware
      ./programs
      ./roles
      ./services
      ./system
      ./info.nix
    ];

    config = {
      home.stateVersion = "25.11";
      _module.args = {inherit nixclyx;};
    };
  }
