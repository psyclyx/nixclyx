{
  path = ["psyclyx" "nvf" "ui"];
  description = "visuals and UI chrome";
  config = _: {
    vim = {
      options = {
        scrolloff = 3;
        cursorline = true;
      };

      theme = {
        enable = true;
        name = "base16";
        transparent = true;
      };

      dashboard.alpha.enable = true;
      statusline.lualine.enable = true;

      ui = {
        borders = {
          enable = true;
          globalStyle = "single";
        };
        breadcrumbs = {
          enable = true;
          navbuddy.enable = true;
        };
        colorizer.enable = true;
        illuminate.enable = true;
        noice = {
          enable = true;
          setupOpts.lsp.signature.enabled = true;
        };
      };

      visuals = {
        rainbow-delimiters.enable = true;
      };
    };
  };
}
