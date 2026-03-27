{
  path = ["psyclyx" "nvf" "binds"];
  description = "keybindings and which-key";
  config = _: {
    vim = {
      globals = {
        maplocalleader = ",";
      };

      binds = {
        whichKey = {
          enable = true;
          register = {
            "<leader>b" = "Buffers";
            "<leader>f" = "Find";
            "<leader>s" = "Search";
            "<leader>q" = "Quit";
            "<leader>e" = "Explorer";
            "<leader>g" = "Git";
            "<leader>l" = "LSP";
            "<leader>u" = "Toggle";
            "<leader>a" = "AI (Avante)";
          };
        };
      };

      keymaps = [
        # buffer management
        {
          mode = "n";
          key = "<leader>bd";
          action = "<cmd>bdelete<cr>";
          desc = "Delete buffer";
        }
        {
          mode = "n";
          key = "<leader>bn";
          action = "<cmd>bnext<cr>";
          desc = "Next buffer";
        }
        {
          mode = "n";
          key = "<leader>bp";
          action = "<cmd>bprevious<cr>";
          desc = "Previous buffer";
        }
        {
          mode = "n";
          key = "<leader><tab>";
          action = "<cmd>b#<cr>";
          desc = "Last buffer";
        }

        # quit
        {
          mode = "n";
          key = "<leader>qq";
          action = "<cmd>qa<cr>";
          desc = "Quit all";
        }

        # search
        {
          mode = "n";
          key = "<leader>sc";
          action = "<cmd>nohlsearch<cr>";
          desc = "Clear highlights";
        }

        # quickfix
        {
          mode = "n";
          key = "]q";
          action = "<cmd>cnext<cr>";
          desc = "Next quickfix";
        }
        {
          mode = "n";
          key = "[q";
          action = "<cmd>cprev<cr>";
          desc = "Previous quickfix";
        }
      ];
    };
  };
}
