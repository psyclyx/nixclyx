let
  base = {
    home = {
      stateVersion = "25.05";
    };
    psyclyx = {
      user = {
        name = "psyclyx";
        email = "me@psyclyx.xyz";
      };
    };
  };
in
{
  nixosServer = {
    imports = [
      base
      { psyclyx.roles.shell = true; }
    ];
  };

  nixosDesktop = {
    imports = [
      base
      {
        psyclyx = {
          gtk.enable = false;
          programs.emacs.enable = true;
          roles = {
            shell = true;
            dev = true;
            graphical = true;
            sway = true;
          };
          secrets.enable = true;
        };
      }
    ];
  };

  darwinDesktop = {
    imports = [
      base
      {
        psyclyx = {
          programs.emacs.enable = true;
          roles = {
            shell = true;
            dev = true;
            graphical = true;
          };
          secrets.enable = true;
        };
      }
    ];
  };
}
