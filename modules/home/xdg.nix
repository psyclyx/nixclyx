{ pkgs, ... }:
{
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "\$HOME/desktop";
      documents = "\$HOME/documents";
      download = "\$HOME/downloads";
      music = "\$HOME/music";
      pictures = "\$HOME/pictures";
      videos = "\$HOME/videos";
      templates = "\$HOME/templates";
      publicShare = "\$HOME/public";
    };

    configFile = {
      "mimeapps.list".force = true;
    };

    mimeApps =
      let
        firefox = "firefox.desktop";
      in
      {
        enable = true;
        associations.added = {
          "application/pdf" = [ firefox ];
          "application/x-extension-htm" = [ firefox ];
          "application/x-extension-html" = [ firefox ];
          "application/x-extension-shtml" = [ firefox ];
          "application/x-extension-xht" = [ firefox ];
          "application/x-extension-xhtml" = [ firefox ];
          "application/xhtml+xml" = [ firefox ];
          "text/html" = [ firefox ];
          "text/markdown" = [ ];
          "text/plain" = [ ];
          "x-scheme-handler/ftp" = [ firefox ];
          "x-scheme-handler/http" = [ firefox ];
          "x-scheme-handler/https" = [ firefox ];
          "x-scheme-handler/unknown" = [ firefox ];
          "x-scheme-handler/about" = [ firefox ];
        };

        defaultApplications = {
          "application/pdf" = [ firefox ];
          "application/x-extension-htm" = [ firefox ];
          "application/x-extension-html" = [ firefox ];
          "application/x-extension-shtml" = [ firefox ];
          "application/x-extension-xht" = [ firefox ];
          "application/x-extension-xhtml" = [ firefox ];
          "application/xhtml+xml" = [ firefox ];
          "text/html" = [ firefox ];
          "text/markdown" = [ ];
          "text/plain" = [ ];
          "x-scheme-handler/ftp" = [ firefox ];
          "x-scheme-handler/http" = [ firefox ];
          "x-scheme-handler/https" = [ firefox ];
          "x-scheme-handler/unknown" = [ firefox ];
          "x-scheme-handler/about" = [ firefox ];
        };
      };
  };
}
