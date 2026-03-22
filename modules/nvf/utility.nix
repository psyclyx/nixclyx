{
  path = ["psyclyx" "nvf" "utility"];
  description = "utility plugins";
  config = _: {
    vim = {
      utility = {
        ccc.enable = true;
        direnv.enable = true;
        mkdir.enable = true;
        motion.precognition = {
          enable = true;
          setupOpts.startVisible = false;
        };
        multicursors.enable = true;
        surround.enable = true;
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>up";
          action = "<cmd>lua require('precognition').toggle()<cr>";
          desc = "Toggle precognition";
        }
      ];
    };
  };
}
