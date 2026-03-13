{
  path = ["psyclyx" "nixos" "programs" "ccache"];
  description = "Enable ccache for C/C++ compilation.";
  config = _: {
    programs.ccache.enable = true;
  };
}
