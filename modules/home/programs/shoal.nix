{
  path = ["psyclyx" "home" "programs" "shoal"];
  description = "Shoal wayland desktop shell toolkit";
  config = { pkgs, ... }: {
    programs.shoal = {
      enable = true;
      package = pkgs.psyclyx.shoal;

      configs.default = {
        # Use the bundled example bar; pass "tidepool" as the
        # compositor selector via script-args.
        modules.bar = ''
          (use "example/bar")
        '';
        args = [ "tidepool" ];

        # The bar binds tidepool's IPC for workspaces/title/marks etc.,
        # so it can't usefully start until tidepool is running.
        systemd = {
          after = [ "graphical-session.target" "tidepool.service" ];
          wants = [ "graphical-session.target" "tidepool.service" ];
        };
      };
    };
  };
}
