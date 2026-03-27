{
  path = ["psyclyx" "nvf" "lsp"];
  description = "LSP, diagnostics, formatting, and completion";
  config = {pkgs, ...}: {
    vim = {
      lsp = {
        enable = true;
        formatOnSave = true;
        inlayHints.enable = true;
        trouble.enable = true;
        lightbulb.enable = true;
        lspkind.enable = true;
      };

      diagnostics = {
        enable = true;
      };

      extraPackages = [pkgs.cljstyle];

      formatter.conform-nvim = {
        enable = true;
        setupOpts = {
          formatters.cljstyle = {
            command = "cljstyle";
            args = ["pipe"];
          };
          formatters_by_ft.clojure = ["cljstyle"];
        };
      };

      autocomplete.blink-cmp = {
        enable = true;
        setupOpts = {
          signature.enabled = true;
          completion.documentation = {
            auto_show = true;
            auto_show_delay_ms = 100;
          };
        };
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>ui";
          action = "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>";
          desc = "Toggle inlay hints";
        }
      ];
    };
  };
}
