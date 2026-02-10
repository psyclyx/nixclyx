{
  path = ["psyclyx" "nixos" "programs" "nvf"];
  description = "nvf (neovim)";
  config = {nixclyx, ...}: {
    programs.nvf = {
      enable = true;
      settings = {imports = [nixclyx.modules.nvf];};
    };
  };
}
