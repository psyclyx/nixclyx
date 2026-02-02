{nixclyx, ...}: {
  imports = [
    nixclyx.darwinModules.psyclyx
    ./users.nix
  ];

  config = {
    nixpkgs.hostPlatform = "aarch64-darwin";

    system.stateVersion = 5;

    networking.hostName = "halo";

    psyclyx = {
      roles = {
        base.enable = true;
        desktop.enable = true;
      };

      services = {
        tailscale.enable = true;
      };
    };

    homebrew.casks = [
      "orcaslicer"
    ];

    stylix = {
      image = nixclyx.assets.wallpapers."2x-ppmm-madoka-homura.png";
    };
  };
}
