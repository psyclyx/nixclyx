{ config, lib, ... }:
let
  cfg = config.psyclyx.programs.zsh;
in
{
  options = {
    psyclyx = {
      programs = {
        zsh = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Let nixos configure zsh (recommended).";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        enableGlobalCompInit = false;
      };
    };
  };
}
