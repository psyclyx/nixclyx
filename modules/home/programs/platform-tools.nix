{
  path = ["psyclyx" "home" "platformTools"];
  description = "Device CLIs (swos, sodola, ilo) on PATH, and HTTP credentials in place.";
  options = { lib, ... }: {
    enable = lib.mkEnableOption "the psyclyx device tools (swos, sodola, ilo)";

    netrc = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an existing netrc — typically a sops-nix secret — installed
        at `~/.netrc`. The tools read per-host HTTP credentials from it by
        `machine <host>`; a per-tool `<TOOL>_USER`/`<TOOL>_PASSWORD` in the
        environment overrides it for ad-hoc targets.
      '';
    };
  };
  config = {
    config,
    lib,
    nixclyx,
    ...
  }:
    lib.mkIf config.psyclyx.home.platformTools.enable {
      home.packages = [
        nixclyx.platformTools.swos
        nixclyx.platformTools.sodola
        nixclyx.platformTools.ilo
      ];

      home.file.".netrc" = lib.mkIf (config.psyclyx.home.platformTools.netrc != null) {
        source = config.psyclyx.home.platformTools.netrc;
      };
    };
}
