{
  path = ["psyclyx" "nixos" "programs" "nvf" "structural"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {pkgs, ...}: {
    vim = {
      startPlugins = [
        pkgs.vimPlugins.vim-sexp
        pkgs.vimPlugins.vim-sexp-mappings-for-regular-people
        pkgs.vimPlugins.vim-repeat
      ];

      globals = {
        sexp_filetypes = "clojure,scheme,lisp,fennel";
      };
    };
  };
}
