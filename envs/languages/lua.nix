pkgs:
pkgs.buildEnv {
  name = "lang-lua";
  paths = [
    # Runtime
    pkgs.lua
    pkgs.luajit

    # Package manager
    pkgs.luarocks

    # LSP
    pkgs.lua-language-server

    # Linters
    pkgs.luajitPackages.luacheck
    pkgs.selene

    # Formatter
    pkgs.stylua
  ];
  meta.description = "Lua development environment - lua, luajit, LSP, linters, formatters";
}
