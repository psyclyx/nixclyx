{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "editing"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      # ── Editing ───────────────────────────────────────────────────
      mini.ai.enable = true;
      mini.surround.enable = true;
      mini.pairs.enable = true;
      mini.comment.enable = true;
      mini.move.enable = true;
      mini.align.enable = true;
      mini.splitjoin.enable = true;
      mini.snippets.enable = true;
    };
  };
}
