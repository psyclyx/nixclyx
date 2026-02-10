{nixclyx}: let
  sources = nixclyx.sources;
  loadFlake = nixclyx.loadFlake;
  pkgs = import sources.nixpkgs {system = "x86_64-linux";};
  lib = pkgs.lib;

  evalConfig = import (sources.nixpkgs + "/nixos/lib/eval-config.nix");
  makeOptionsDoc = import (sources.nixpkgs + "/nixos/lib/make-options-doc/default.nix");

  nixosEval = evalConfig {
    system = "x86_64-linux";
    modules = [
      nixclyx.modules.nixos.options
      nixclyx.modules.nixos.config
      {
        # Satisfy required enums so option evaluation doesn't error.
        # The actual values don't affect option definitions.
        psyclyx.nixos.host = "sigil";
        psyclyx.nixos.role = "workstation";
        psyclyx.nixos.system.home-manager.enable = true;
        home-manager.users.psyc.psyclyx.home.variant = "workstation";
      }
    ];
  };

  hmOpts = nixosEval.options.home-manager.users.type.getSubOptions [];

  darwinEval = (loadFlake sources.nix-darwin).lib.darwinSystem {
    modules = [
      nixclyx.modules.darwin.options
      nixclyx.modules.darwin.config
      {
        nixpkgs.hostPlatform = "aarch64-darwin";
        psyclyx.darwin.system.home-manager.enable = true;
      }
    ];
  };

  mkDoc = options:
    makeOptionsDoc {
      inherit pkgs lib options;
      warningsAreErrors = false;
      transformOptions = opt: opt // {declarations = [];};
    };

  nixosDocs = mkDoc {psyclyx = nixosEval.options.psyclyx;};
  homeDocs = mkDoc {psyclyx = hmOpts.psyclyx;};
  darwinDocs = mkDoc {psyclyx = darwinEval.options.psyclyx;};
in
  pkgs.runCommand "psyclyx-docs" {
    nativeBuildInputs = [pkgs.python3];
  } ''
      mkdir -p $out

      toHtml() {
        local title="$1" json="$2" prefix="$3" dest="$4"
        python3 ${./render.py} --title "$title" --prefix "$prefix" "$json" > "$dest"
      }

      toHtml "NixOS"  ${nixosDocs.optionsJSON}/share/doc/nixos/options.json  "psyclyx.nixos."  $out/nixos.html
      toHtml "Home"   ${homeDocs.optionsJSON}/share/doc/nixos/options.json   "psyclyx.home."   $out/home.html
      toHtml "Darwin" ${darwinDocs.optionsJSON}/share/doc/nixos/options.json "psyclyx.darwin."  $out/darwin.html

      cat > $out/index.html <<'EOF'
    <!DOCTYPE html><html lang="en"><head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>psyclyx options</title>
    <style>
    body{font-family:system-ui,sans-serif;max-width:56em;margin:2em auto;padding:0 1em;line-height:1.6;color:#1a1a1a}
    a{color:#0057b7}
    h1{border-bottom:2px solid #e0e0e0;padding-bottom:.3em}
    ul{list-style:none;padding:0}
    li{margin:.8em 0}
    li a{font-size:1.1em}
    code{background:#f0f0f0;padding:.15em .35em;border-radius:3px;font-size:.9em}
    </style>
    </head><body>
    <h1>psyclyx options</h1>
    <ul>
      <li><a href="nixos.html">NixOS</a> &mdash; <code>psyclyx.nixos.*</code>, <code>psyclyx.common.*</code></li>
      <li><a href="home.html">Home Manager</a> &mdash; <code>psyclyx.home.*</code></li>
      <li><a href="darwin.html">Darwin</a> &mdash; <code>psyclyx.darwin.*</code></li>
    </ul>
    </body></html>
    EOF
  ''
