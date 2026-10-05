{
  path = ["psyclyx" "darwin" "system" "nix"];
  description = "nix config";
  options = {lib, ...}: {
    determinate = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Nix on this host is Determinate Nix, which owns its daemon and
        /etc/nix/nix.conf. nix-darwin then leaves Nix alone, and settings go
        to /etc/nix/nix.custom.conf, which Determinate's nix.conf includes.
      '';
    };
  };
  config = {
    cfg,
    lib,
    nixclyx,
    ...
  }:
    lib.mkMerge [
      (lib.mkIf (!cfg.determinate) {
        psyclyx.common.system.nix.enable = true;
        nix.settings.trusted-users = ["@admin"];

        # Early Monday, staggered so gc finishes before optimise starts.
        nix.gc.interval = {
          Weekday = 1;
          Hour = 5;
          Minute = 0;
        };
        nix.optimise.interval = {
          Weekday = 1;
          Hour = 6;
          Minute = 0;
        };
      })

      (lib.mkIf cfg.determinate {
        nix.enable = false;

        # extra-* appends to Determinate's own defaults (cache.nixos.org,
        # FlakeHub) instead of replacing them.
        environment.etc."nix/nix.custom.conf".text = let
          inherit (nixclyx.nixCaches) substituters trusted-substituters trusted-public-keys;
        in ''
          extra-substituters = ${toString substituters}
          extra-trusted-substituters = ${toString trusted-substituters}
          extra-trusted-public-keys = ${toString trusted-public-keys}
          trusted-users = root @admin
        '';
      })
    ];
}
