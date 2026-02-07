{
  path = ["psyclyx" "home" "config" "homes" "psyc" "workstation"];
  variant = ["psyclyx" "home" "variant"];
  config = {lib, pkgs, ...}: {
    home.packages = [
      pkgs.element-desktop
      pkgs.firefox-bin
      pkgs.signal-desktop-bin
    ];

    psyclyx.home = {
      programs = {
        alacritty.enable = true;
        claude-code.enable = true;
        ghostty = {
          enable = true;
          defaultTerminal = true;
        };
        sway.enable = true;
      };
    };
  };
}
