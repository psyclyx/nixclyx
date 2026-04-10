{
  # Essential CLI tools — every host, including mobile.
  core = pkgs: [
    # File utilities
    pkgs.file
    pkgs.moreutils
    (pkgs.lib.meta.hiPrio pkgs.parallel)
    pkgs.ripgrep
    pkgs.fd
    pkgs.tree
    pkgs.pv

    # Compression
    pkgs.zip
    pkgs.unzip
    pkgs.p7zip

    # Network diagnostics
    pkgs.wget
    pkgs.bind # dig, nslookup
    pkgs.ethtool
    pkgs.mtr
    pkgs.traceroute
    pkgs.iperf3
    pkgs.iproute2
    pkgs.wireguard-tools
    pkgs.tcpdump

    # System monitoring
    pkgs.btop
    pkgs.duf
    pkgs.ncdu
    pkgs.lsof
    pkgs.iotop
    pkgs.psmisc

    # Terminal
    pkgs.tmux
    pkgs.dtach

    # Editor and VCS
    pkgs.vim
    pkgs.git
  ];

  # Interactive shell experience — servers and workstations.
  shell = pkgs: [
    # Shell enhancements
    pkgs.fzf
    pkgs.bat
    pkgs.eza

    # Extra archive tools
    pkgs.unar
    pkgs.btar

    # Transfer tools
    pkgs.aria2
    pkgs.rclone
    pkgs.magic-wormhole

    # Extra terminal tools
    pkgs.screen
    pkgs.shpool
    pkgs.reptyr

    # TUI apps
    pkgs.lazygit
    pkgs.yazi

    # Forensics
    pkgs.sleuthkit
  ];

  # Media processing — workstations only.
  media = pkgs: [
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

    # Infra / Ops
    pkgs.openbao
    pkgs.kubectl
    pkgs.kubernetes-helm
    pkgs.k9s
    pkgs.kustomize
    pkgs.stern
    pkgs.skopeo

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

    # Janet
    pkgs.janet
    pkgs.jpm

    # Mobile
    pkgs.android-tools
  ];
}
