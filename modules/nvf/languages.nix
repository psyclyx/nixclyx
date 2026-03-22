{
  path = ["psyclyx" "nvf" "languages"];
  description = "language support and treesitter";
  config = {pkgs, ...}: {
    vim = {
      languages = {
        enableDAP = true;
        enableExtraDiagnostics = true;
        enableFormat = true;
        enableTreesitter = true;
        assembly.enable = true;
        bash.enable = true;
        clojure.enable = true;
        clang.enable = true;
        haskell.enable = true;
        html.enable = true;
        java.enable = true;
        json.enable = true;
        julia.enable = true;
        just.enable = true;
        lua.enable = true;
        markdown.enable = true;
        nix.enable = true;
        ocaml.enable = true;
        # odin.enable = true; # disabled: ols broken with current nixpkgs (using-stmt)
        python.enable = true;
        rust = {
          enable = true;
          extensions.crates-nvim.enable = true;
        };
        sql.enable = true;
        ts.enable = true;
        wgsl.enable = true;
        yaml.enable = true;
        zig.enable = true;
      };

      treesitter = {
        autotagHtml = true;
        context.enable = true;
        fold = true;
        grammars = [pkgs.vimPlugins.nvim-treesitter-parsers.janet_simple];
        textobjects.enable = true;
      };
    };
  };
}
