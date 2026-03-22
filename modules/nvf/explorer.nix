{
  path = ["psyclyx" "nvf" "explorer"];
  description = "file explorer (mini.files)";
  config = {pkgs, lib, ...}: {
    vim = {
      extraPlugins.mini-files = {
        package = pkgs.vimPlugins.mini-nvim;
        setup = ''require("mini.files").setup({})'';
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>fe";
          action = "<cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<cr>";
          desc = "File explorer (current file)";
        }
        {
          mode = "n";
          key = "<leader>ee";
          action = "<cmd>lua MiniFiles.open()<cr>";
          desc = "File explorer (cwd)";
        }
      ];

      luaConfigRC.mini-files-keymaps = lib.nvim.dag.entryAnywhere ''
        local function mini_files_split(buf_id, direction)
          local rhs = function()
            local new_target_window
            vim.api.nvim_win_call(MiniFiles.get_target_window(), function()
              vim.cmd(direction .. " split")
              new_target_window = vim.api.nvim_get_current_win()
            end)
            MiniFiles.set_target_window(new_target_window)
            MiniFiles.go_in({ close_on_file = true })
          end
          local desc = direction:sub(1, 1):upper() .. direction:sub(2) .. " split"
          vim.keymap.set("n", direction == "horizontal" and "<C-x>" or "<C-v>", rhs, { buffer = buf_id, desc = desc })
        end

        vim.api.nvim_create_autocmd("User", {
          pattern = "MiniFilesBufferCreate",
          callback = function(args)
            local buf_id = args.data.buf_id
            vim.keymap.set("n", "<CR>", function()
              MiniFiles.go_in({ close_on_file = true })
            end, { buffer = buf_id, desc = "Open file and close explorer" })
            vim.keymap.set("n", "<Esc>", MiniFiles.close, { buffer = buf_id, desc = "Close explorer" })
            mini_files_split(buf_id, "horizontal")
            mini_files_split(buf_id, "vertical")
          end,
        })
      '';
    };
  };
}
