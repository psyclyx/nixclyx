{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "ui"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {lib, ...}: let
    inherit (lib.generators) mkLuaInline;
  in {
    vim = {
      # ── UI ────────────────────────────────────────────────────────
      mini.statusline.enable = true;
      mini.tabline.enable = true;
      mini.icons.enable = true;
      mini.starter = {
        enable = true;
        setupOpts.items = [
          (mkLuaInline "require('mini.starter').sections.sessions(5, true)")
          (mkLuaInline "require('mini.starter').sections.recent_files(5, false, false)")
          (mkLuaInline "require('mini.starter').sections.builtin_actions()")
          {
            name = "File explorer";
            action = "lua MiniFiles.open()";
            section = "Actions";
          }
        ];
      };
      mini.notify.enable = true;
      mini.indentscope.enable = true;
      mini.cursorword.enable = true;
      mini.animate.enable = true;
      mini.map.enable = true;

      mini.hipatterns = {
        enable = true;
        setupOpts = {
          highlighters = {
            fixme = {
              pattern = "%f[%w]()FIXME()%f[%W]";
              group = "MiniHipatternsFixme";
            };
            hack = {
              pattern = "%f[%w]()HACK()%f[%W]";
              group = "MiniHipatternsHack";
            };
            todo = {
              pattern = "%f[%w]()TODO()%f[%W]";
              group = "MiniHipatternsTodo";
            };
            note = {
              pattern = "%f[%w]()NOTE()%f[%W]";
              group = "MiniHipatternsNote";
            };
            hex_color = mkLuaInline "require('mini.hipatterns').gen_highlighter.hex_color()";
          };
        };
      };
    };
  };
}
