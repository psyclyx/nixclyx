{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;

  linux = {
    home = {
      packages = with pkgs; [
        psyclyx.upscale-image
        firefox-bin
        signal-desktop-bin
      ];
    };

    psyclyx = {
      gtk = {
        enable = lib.mkDefault true;
      };
      programs = {
        alacritty = {
          enable = lib.mkDefault true;
        };
      };
      xdg = {
        enable = lib.mkDefault true;
      };
    };
  };

  darwin = {
    psyclyx = {
      programs = {
        kitty = {
          enable = lib.mkDefault true;
        };
      };
    };
  };

  cfgEnabled = config.psyclyx.roles.graphical;
in
{
  options = {
    psyclyx = {
      roles = {
        graphical = lib.mkEnableOption "graphical session programs/config";
      };
    };
  };

  config = lib.mkIf cfgEnabled (
    lib.mkMerge [
      (lib.mkIf isLinux linux)
      (lib.mkIf isDarwin darwin)
    ]
  );
}
