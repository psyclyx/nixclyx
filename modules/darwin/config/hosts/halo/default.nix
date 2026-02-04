{
  config,
  lib,
  nixclyx,
  ...
}: let
  cfg = config.psyclyx.darwin.config.hosts.halo;
in {
  options.psyclyx.darwin.config.hosts.halo = {
    enable = lib.mkEnableOption "halo host";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "aarch64-darwin";

    networking.hostName = "halo";

    psyclyx.darwin.config = {
      roles = {
        base.enable = true;
        desktop.enable = true;
      };
      users.psyc.base.enable = true;
    };

    psyclyx.darwin.services.tailscale.enable = true;

    homebrew.casks = [
      "orcaslicer"
    ];

    stylix = {
      image = nixclyx.assets.wallpapers."2x-ppmm-madoka-homura.png";
    };
  };
}
