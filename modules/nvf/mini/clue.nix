{
  path = ["psyclyx" "nixos" "programs" "nvf" "mini" "clue"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {lib, ...}: let
    inherit (lib.generators) mkLuaInline;
  in {
    vim = {
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
    };
  };
}
