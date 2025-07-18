{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles;
  shell = {
    home = {
      packages = with pkgs; [
        fd
        ripgrep
      ];
    };
    psyclyx = {
      programs = {
        ssh = {
          enable = lib.mkDefault true;
        };
        zsh = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
  dev = {
    psyclyx = {
      programs = {
        git = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
  graphical = {
    home = {
      packages = with pkgs; [
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
  sway = {
    psyclyx = {
      programs = {
        sway = {
          enable = lib.mkDefault true;
        };
        waybar = {
          enable = lib.mkDefault true;
        };
      };
    };
  };
in
{
  options = {
    psyclyx = {
      roles = {
        shell = lib.mkEnableOption "basic shell config";
        dev = lib.mkEnableOption "dev tools/config";
        graphical = lib.mkEnableOption "graphical session programs/config";
        sway = lib.mkEnableOption "sway, etc";
      };
    };
  };
  config = lib.mkMerge ([
    (lib.mkIf cfg.shell shell)
    (lib.mkIf cfg.dev dev)
    (lib.mkIf cfg.graphical graphical)
    (lib.mkIf cfg.sway sway)
  ]);
}
