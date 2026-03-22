{
  path = ["psyclyx" "nvf" "telescope"];
  description = "telescope fuzzy finder";
  config = {pkgs, ...}: {
    vim = {
      telescope = {
        enable = true;
        setupOpts.defaults.vimgrep_arguments = [
          "${pkgs.ripgrep}/bin/rg"
          "--color=never"
          "--no-heading"
          "--with-filename"
          "--line-number"
          "--column"
          "--smart-case"
        ];
        extensions = [
          {
            name = "fzf";
            packages = [pkgs.vimPlugins.telescope-fzf-native-nvim];
            setup = {
              fzf = {
                fuzzy = true;
                override_generic_sorter = true;
                override_file_sorter = true;
                case_mode = "smart_case";
              };
            };
          }
        ];
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>,";
          action = "<cmd>Telescope buffers<cr>";
          desc = "Open buffers";
        }
        {
          mode = "n";
          key = "<leader>/";
          action = "<cmd>Telescope live_grep<cr>";
          desc = "Grep in project";
        }
        {
          mode = "n";
          key = "<leader>fo";
          action = "<cmd>Telescope oldfiles<cr>";
          desc = "Recent files";
        }
        {
          mode = "n";
          key = "<leader>fk";
          action = "<cmd>Telescope keymaps<cr>";
          desc = "Keybindings";
        }
      ];
    };
  };
}
