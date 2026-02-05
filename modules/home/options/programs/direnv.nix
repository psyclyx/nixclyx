{
  path = ["psyclyx" "home" "programs" "direnv"];
  description = "direnv";
  config = _: {
    programs.direnv = {
      enable = true;
      silent = true;
      nix-direnv.enable = true;
    };
  };
}
