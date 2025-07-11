{ pkgs, ... }:
{
  services = {
    greetd = {
      enable = true;
      vt = 2;
      settings = {
        default_session.command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --user-menu --remember --asterisks --cmd sway";
        user = "greeter";
      };
    };
  };
}
