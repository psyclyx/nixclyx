{
  path = ["psyclyx" "nvf" "vcs"];
  description = "version control (git)";
  config = _: {
    vim = {
      git = {
        enable = true;
        gitsigns.mappings = {
          nextHunk = "]c";
          previousHunk = "[c";
          stageHunk = "<leader>gs";
          undoStageHunk = "<leader>gu";
          resetHunk = "<leader>gr";
          stageBuffer = "<leader>gS";
          resetBuffer = "<leader>gR";
          previewHunk = "<leader>gp";
          blameLine = "<leader>gb";
          toggleBlame = "<leader>gB";
          diffThis = "<leader>gd";
          diffProject = "<leader>gD";
          toggleDeleted = "<leader>gx";
        };
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>gg";
          action = "<cmd>Git<cr>";
          desc = "Git status";
        }
        {
          mode = "n";
          key = "<leader>gl";
          action = "<cmd>Git log<cr>";
          desc = "Git log";
        }
        {
          mode = "n";
          key = "<leader>gc";
          action = "<cmd>Git commit<cr>";
          desc = "Git commit";
        }
      ];
    };
  };
}
