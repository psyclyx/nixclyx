{
  path = ["psyclyx" "nixos" "system" "locale"];
  description = "Locale config";
  options = {lib, ...}: {
    default = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Default locale.";
    };
    extraSupported = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["en_GB.UTF-8"];
      description = ''
        Additional UTF-8 locales to generate. Listed in the
        nixos `i18n.supportedLocales` form (`<lang>.UTF-8`); the
        `/UTF-8` charmap suffix is appended automatically. The
        default locale and `C.UTF-8` are always included.
      '';
    };
  };
  config = {cfg, lib, ...}: {
    i18n.defaultLocale = cfg.default;
    i18n.supportedLocales = lib.unique (
      ["C.UTF-8/UTF-8" "${cfg.default}/UTF-8"]
      ++ map (l: "${l}/UTF-8") cfg.extraSupported
    );
  };
}
