{
  path = ["psyclyx" "droid" "hosts" "phone"];
  variant = ["psyclyx" "droid" "host"];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    environment.packages = [
      pkgs.fzf
      pkgs.bat
      pkgs.eza
      pkgs.lazygit
      pkgs.yazi
      pkgs.aria2
      pkgs.rclone
      pkgs.magic-wormhole
      pkgs.nix-tree
    ];

    psyclyx.droid.roles.base.enable = true;

    terminal.font = "${pkgs.aporetic}/share/fonts/opentype/AporeticSansMono-Regular.otf";

    stylix = {
      enable = true;
      image = "${nixclyx.assets}/wallpapers/4x-ppmm-mami.jpg";
      base16Scheme = "${nixclyx.assets}/palettes/4x-ppmm-mami.yaml";
      polarity = "dark";
      fonts.monospace = {
        package = pkgs.aporetic;
        name = "Aporetic Sans Mono";
      };
    };

    home-manager.config = {
      psyclyx.home = {
        info = {
          name = "psyclyx";
          email = "me@psyclyx.xyz";
        };

        programs = {
          git.enable = true;
          zsh.enable = lib.mkDefault true;
        };

        xdg.enable = true;
      };
    };
  };
}
