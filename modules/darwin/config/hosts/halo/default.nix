{
  path = ["psyclyx" "darwin" "config" "hosts" "halo"];
  variant = ["psyclyx" "darwin" "host"];
  config = {
    lib,
    nixclyx,
    ...
  }: {
    nixpkgs.hostPlatform = "aarch64-darwin";

    networking.hostName = "halo";

    psyclyx.darwin.config = {
      roles = {
        base.enable = true;
        desktop.enable = true;
      };
      users.psyc.enable = true;
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
