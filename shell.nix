let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {
    overlays = [(import ./overlay.nix)];
    config = {
      allowUnfree = true;
      nvidia.acceptLicense = true;
    };
  };
in
  pkgs.mkShell {
    packages = with pkgs; [
      pkgs.colmena.colmena
      nixfmt
      nixd
      nix-tree
      pkgs.psyclyx.regenerate-palettes
      pkgs.psyclyx.egregore
      sops
      ssh-to-age
      yq
    ];

    shellHook = ''
      # Enable completions from nix shell packages.
      for p in $nativeBuildInputs; do
        if [[ -n "''${ZSH_VERSION:-}" && -d "$p/share/zsh/site-functions" ]]; then
          fpath+=("$p/share/zsh/site-functions")
        fi
        if [[ -n "''${BASH_VERSION:-}" && -d "$p/share/bash-completion/completions" ]]; then
          for f in "$p/share/bash-completion/completions/"*; do
            source "$f" 2>/dev/null
          done
        fi
      done
      if [[ -n "''${ZSH_VERSION:-}" ]]; then
        autoload -Uz compinit && compinit -C
      fi
    '';
  }
