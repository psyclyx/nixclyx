{ ... }:
let
  c = import ../../nixos/colors.nix;
in
{
  programs.waybar = {
    style = ''
      * {
          padding: 0;
          margin: 0;
          border: none;
          min-height: 0;
          box-shadow: none;
          border-radius: 0;
      }


      widget > * {
          padding: 0px 16px;
      }

      window, #workspaces {
          margin-bottom: 0;
          padding-bottom: 0;
      }

      button:hover {
          box-shadow: none;
          text-shadow: none;
          background: inherit;
          transition: none;
          color: inherit;
      }

      #workspaces button:not(:first-child) {
          margin-left: 16px;
      }
    '';
  };
}
