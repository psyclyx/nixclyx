{
  path = ["psyclyx" "home" "programs" "rbw"];
  description = "rbw (Bitwarden CLI)";
  options = {
    config,
    lib,
    pkgs,
    ...
  }: {
    email = lib.mkOption {
      type = lib.types.str;
      description = "Email address for Bitwarden account";
    };
    pinentry = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pinentry-gnome3;
      description = "Pinentry program for master password entry";
    };
  };
  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: {
    psyclyx.home.programs.rbw.email = lib.mkDefault config.psyclyx.home.info.email;
    programs.rbw = {
      enable = true;
      settings = {
        email = cfg.email;
        pinentry = cfg.pinentry;
      };
    };
  };
}
