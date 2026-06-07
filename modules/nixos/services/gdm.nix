{
  path = ["psyclyx" "nixos" "services" "gdm"];
  description = "GNOME Display Manager";
  config = {
    config,
    pkgs,
    ...
  }: {
    services.displayManager.gdm = {
      enable = true;
    };

    # GDM 50's greeter exec's gnome-session but gdm-launch-environment PAM
    # doesn't inherit PATH/XDG_DATA_DIRS — gnome-session-wayland@.target is
    # then absent from the user manager's search path and session-init traps.
    # Workaround for nixpkgs#523332; drop once nixpkgs#523948 lands.
    security.pam.services.gdm-launch-environment.rules.session.env-greeter-path = {
      order = 10350;
      control = "required";
      modulePath = "${config.security.pam.package}/lib/security/pam_env.so";
      settings.conffile = pkgs.writeText "gdm-launch-environment-env-conf" ''
        PATH          DEFAULT="''${PATH}:${pkgs.gnome-session}/bin"
        XDG_DATA_DIRS DEFAULT="''${XDG_DATA_DIRS}:${config.services.displayManager.generic.environment.XDG_DATA_DIRS}"
      '';
      settings.readenv = 0;
    };
  };
}
