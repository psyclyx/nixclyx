{
  path = ["psyclyx" "home" "profiles" "psyc" "desktop"];
  description = "psyc desktop home config";
  config = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = [
      pkgs.element-desktop
      pkgs.signal-desktop
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = true;
        claude-code.enable = true;
        firefox.enable = true;
        ghostty = {
          enable = true;
          defaultTerminal = true;
        };
        sway.enable = true;
      };
    };
  };
}
