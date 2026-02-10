{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "utility"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      # ── Utility ───────────────────────────────────────────────────
      mini.bufremove.enable = true;
      mini.trailspace.enable = true;
      mini.sessions.enable = true;
    };
  };
}
