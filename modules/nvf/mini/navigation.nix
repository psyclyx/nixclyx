{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "navigation"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {lib, ...}: let
    inherit (lib.generators) mkLuaInline;
  in {
    vim = {
      # ── Navigation & finding ──────────────────────────────────────
      mini.files = {
        enable = true;
        setupOpts.options.use_as_default_explorer = true;
      };
      mini.visits.enable = true;
      mini.jump.enable = true;
      mini.jump2d.enable = true;
      mini.bracketed.enable = true;

      autocmds = [
        {
          event = ["User"];
          pattern = ["MiniFilesBufferCreate"];
          desc = "Map Enter to open file in mini.files";
          callback = mkLuaInline ''
            function(args)
              vim.keymap.set('n', '<CR>', function()
                MiniFiles.go_in({ close_on_file = true })
              end, { buffer = args.data.buf_id, desc = 'Open file' })
            end
          '';
        }
      ];
    };
  };
}
