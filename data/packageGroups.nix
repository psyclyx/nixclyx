{
  shell = pkgs: [
    # Text and file utilities
    pkgs.file
    pkgs.moreutils
    (pkgs.lib.meta.hiPrio pkgs.parallel)
    pkgs.ripgrep
    pkgs.fd
    pkgs.fzf
    pkgs.bat
    pkgs.eza
    pkgs.tree
    pkgs.pv
    pkgs.sleuthkit

    # Compression and archiving
    pkgs.zip
    pkgs.unzip
    pkgs.p7zip
    pkgs.unar
    pkgs.btar

    # Network tools
    pkgs.wget
    pkgs.aria2
    pkgs.rclone
    pkgs.magic-wormhole
    pkgs.bind # dig, nslookup
    pkgs.ethtool
    pkgs.mtr
    pkgs.traceroute
    pkgs.iperf3
    pkgs.iproute2
    pkgs.wireguard-tools

    # System monitoring
    pkgs.btop
    pkgs.duf
    pkgs.ncdu
    pkgs.lsof
    pkgs.iotop
    pkgs.psmisc

    # Terminal multiplexing and process management
    pkgs.tmux
    pkgs.screen
    pkgs.shpool
    pkgs.dtach
    pkgs.reptyr

    # Editor and VCS
    pkgs.vim
    pkgs.git
    pkgs.lazygit
    pkgs.yazi

    # Encoding tools
    pkgs.ffmpeg
    pkgs.imagemagick
  ];

  dev = pkgs: [
    # C/C++
    pkgs.gcc
    pkgs.clang
    pkgs.gnumake
    pkgs.cmake
    pkgs.meson
    pkgs.ninja
    pkgs.gdb
    pkgs.lldb
    pkgs.clang-tools # provides clangd
    pkgs.valgrind
    pkgs.ccache

    # Java / Clojure
    pkgs.temurin-bin
    pkgs.clojure
    pkgs.leiningen
    pkgs.babashka
    pkgs.neil
    pkgs.jet
    pkgs.clojure-lsp
    pkgs.clj-kondo

    # Lua
    pkgs.lua
    pkgs.luarocks
    pkgs.lua-language-server
    pkgs.luajitPackages.luacheck
    pkgs.selene
    pkgs.stylua

    # Nix
    pkgs.colmena.colmena
    pkgs.nil
    pkgs.npins
    pkgs.nixd
    pkgs.statix
    pkgs.deadnix
    pkgs.nixfmt
    pkgs.nixfmt-tree
    pkgs.alejandra
    pkgs.nix-tree
    pkgs.nix-diff

    # JavaScript / TypeScript
    pkgs.nodejs
    pkgs.yarn
    pkgs.pnpm
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.vscode-langservers-extracted
    pkgs.nodePackages.eslint
    pkgs.nodePackages.prettier
    pkgs.nodePackages.node-gyp

    # Rust
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.clippy
    pkgs.rust-analyzer
    pkgs.cargo-watch
    pkgs.cargo-edit
    pkgs.cargo-outdated
    pkgs.cargo-audit

    # Zig
    pkgs.zig
    pkgs.zls

    # Mobile
    pkgs.android-tools
  ];
}
