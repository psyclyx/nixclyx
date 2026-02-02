{
  config,
  lib,
  ...
}: let
  inherit (lib.generators) mkLuaInline;
in {
  config.programs.nvf.settings.vim = {
    # ── Navigation & finding ──────────────────────────────────────
    mini.files = {
      enable = true;
      setupOpts.options.use_as_default_explorer = true;
    };
    mini.pick.enable = true;
    mini.extra.enable = true;
    mini.fuzzy.enable = true;
    mini.visits.enable = true;
    mini.jump.enable = true;
    mini.jump2d.enable = true;
    mini.bracketed.enable = true;

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

    mini.clue = {
      enable = true;
      setupOpts = {
        triggers = [
          {
            mode = "n";
            keys = "<Leader>";
          }
          {
            mode = "x";
            keys = "<Leader>";
          }
          {
            mode = "n";
            keys = "g";
          }
          {
            mode = "x";
            keys = "g";
          }
          {
            mode = "n";
            keys = "'";
          }
          {
            mode = "x";
            keys = "'";
          }
          {
            mode = "n";
            keys = "`";
          }
          {
            mode = "x";
            keys = "`";
          }
          {
            mode = "n";
            keys = "\"";
          }
          {
            mode = "x";
            keys = "\"";
          }
          {
            mode = "i";
            keys = "<C-r>";
          }
          {
            mode = "c";
            keys = "<C-r>";
          }
          {
            mode = "n";
            keys = "<C-w>";
          }
          {
            mode = "n";
            keys = "z";
          }
          {
            mode = "x";
            keys = "z";
          }
        ];
        clues = [
          (mkLuaInline "require('mini.clue').gen_clues.builtin_completion()")
          (mkLuaInline "require('mini.clue').gen_clues.g()")
          (mkLuaInline "require('mini.clue').gen_clues.marks()")
          (mkLuaInline "require('mini.clue').gen_clues.registers()")
          (mkLuaInline "require('mini.clue').gen_clues.windows()")
          (mkLuaInline "require('mini.clue').gen_clues.z()")
          {
            mode = "n";
            keys = "<Leader>b";
            desc = "+buffer";
          }
          {
            mode = "n";
            keys = "<Leader>c";
            desc = "+code";
          }
          {
            mode = "n";
            keys = "<Leader>f";
            desc = "+file";
          }
          {
            mode = "n";
            keys = "<Leader>g";
            desc = "+git";
          }
          {
            mode = "n";
            keys = "<Leader>h";
            desc = "+help";
          }
          {
            mode = "n";
            keys = "<Leader>p";
            desc = "+project";
          }
          {
            mode = "n";
            keys = "<Leader>q";
            desc = "+quit";
          }
          {
            mode = "n";
            keys = "<Leader>s";
            desc = "+search";
          }
          {
            mode = "n";
            keys = "<Leader>t";
            desc = "+toggle";
          }
          {
            mode = "n";
            keys = "<Leader>w";
            desc = "+window";
          }
          {
            mode = "n";
            keys = "<Leader>x";
            desc = "+extras";
          }
        ];
        window = {
          delay = 200;
        };
      };
    };

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
}
