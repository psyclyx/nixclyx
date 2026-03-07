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
      default = config.psyclyx.home.info.email;
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
    pkgs,
    ...
  }: {
    programs.rbw = {
      enable = true;
      settings = {
        email = cfg.email;
        pinentry = cfg.pinentry;
      };
    };
  };
}
