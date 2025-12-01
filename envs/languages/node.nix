pkgs:
pkgs.buildEnv {
  name = "lang-node";
  paths = [
    # Runtime
    pkgs.nodejs

    # Package managers
    pkgs.yarn
    pkgs.pnpm

    # LSP
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.vscode-langservers-extracted

    # Linters
    pkgs.nodePackages.eslint

    # Formatters
    pkgs.nodePackages.prettier

    # Build tools
    pkgs.nodePackages.node-gyp
  ];
  meta.description = "Node.js development environment - nodejs, package managers, LSP, linters, formatters";
}
