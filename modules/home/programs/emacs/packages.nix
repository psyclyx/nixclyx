{
  emacsPackages =
    epkgs: with epkgs; [
      # Emacs
      exec-path-from-shell
      dirvish
      general
      no-littering
      undo-tree
      wgrep
      helpful

      # Evil
      evil
      evil-collection
      evil-easymotion
      evil-goggles
      evil-org
      evil-snipe

      # Completion
      cape
      consult
      corfu
      embark
      embark-consult
      marginalia
      orderless
      vertico

      # UI
      rainbow-delimiters
      zenburn-theme

      # Notes
      gptel
      evedel
      org

      # Development
      apheleia
      direnv
      eglot
      envrc
      flycheck
      logview
      magit
      projectile
      smartparens
      evil-cleverparens
      treesit-grammars.with-all-grammars
      vterm

      ## Languages
      cider
      clojure-mode
      flycheck-clj-kondo
      lua-mode
      nix-ts-mode
      rust-mode
      slime
      zig-mode
    ];

  systemPackages =
    pkgs:
    with pkgs;
    [
      # UI
      aporetic
      etBook
      fontconfig
      symbola
      dejavu_fonts

      # Development
      direnv
      git

      ## Search/Completion
      fd
      gnugrep
      ripgrep
      silver-searcher

      # Language support
      ## text
      ispell

      ## clojure
      babashka
      clj-kondo
      cljfmt
      leiningen
      readline
      zlib

      ## Common lisp
      sbcl
      ecl

      ## rust
      cargo
      rust-analyzer
      rustc
      rustfmt

      ## nix
      nixfmt-rfc-style
      nixd

      ## shell
      shellcheck
      shfmt

      ## typescript
      eclint
      nodePackages.prettier
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodejs

      ## zig
      zls
    ]
    ++ lib.optionals stdenv.isDarwin [ ]
    ++ lib.optionals stdenv.isLinux [ ];
}
