{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "editing"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {lib, ...}: let
    inherit (lib.generators) mkLuaInline;
  in {
    vim = {
      # ── Editing ───────────────────────────────────────────────────
      mini.ai.enable = true;
      mini.surround.enable = true;
      mini.operators.enable = true;
      mini.pairs.enable = true;
      mini.comment.enable = true;
      mini.move.enable = true;
      mini.align.enable = true;
      mini.splitjoin.enable = true;
      mini.snippets.enable = true;

      # ── Completion ────────────────────────────────────────────────
      mini.completion = {
        enable = true;
        setupOpts = {
          lsp_completion = {
            source_func = "omnifunc";
            auto_setup = true;
          };
          delay = {
            completion = 50;
            signature = 50;
          };
        };
      };

      # ── Autocmds ──────────────────────────────────────────────────
      autocmds = [
        {
          event = ["LspAttach"];
          desc = "Wire up mini.completion LSP omnifunc";
          callback = mkLuaInline ''
            function(args)
              vim.bo[args.buf].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
            end
          '';
        }
      ];
    };
  };
}
