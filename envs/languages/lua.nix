pkgs:
pkgs.buildEnv {
  name = "lang-lua";
  paths = [
    pkgs.lua

    pkgs.luarocks

    pkgs.lua-language-server

    pkgs.luajitPackages.luacheck
    pkgs.selene

    pkgs.stylua
  ];
  meta.description = "Lua development environment - lua, luajit, LSP, linters, formatters";
}
