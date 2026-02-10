{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "utility"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      # ── Git ────────────────────────────────────────────────────────
      mini.git.enable = true;
      mini.diff.enable = true;

      # ── Utility ───────────────────────────────────────────────────
      mini.bufremove.enable = true;
      mini.trailspace.enable = true;
      mini.sessions.enable = true;
      mini.misc.enable = true;
      mini.basics = {
        enable = true;
        setupOpts = {
          options = {
            basic = true;
            extra_ui = true;
            win_borders = "default";
          };
          mappings = {
            basic = true;
            option_toggle_prefix = "\\";
            windows = false;
            move_with_alt = false;
          };
          autocommands = {
            basic = true;
          };
        };
      };
    };
  };
}
