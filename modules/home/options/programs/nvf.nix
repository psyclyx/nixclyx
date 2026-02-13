{
  path = ["psyclyx" "home" "programs" "nvf"];
  description = "nvf (neovim)";
  options = {lib, ...}: {
    anthropicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing Anthropic API key (read at neovim startup)";
    };
  };
  config = {
    cfg,
    nixclyx,
    ...
  }: {
    programs.nvf = {
      enable = true;
      settings = {
        imports = [nixclyx.modules.nvf];
        psyclyx.nixos.programs.nvf.enable = true;
        psyclyx.nixos.programs.nvf.anthropicKeyFile = cfg.anthropicKeyFile;
      };
    };
  };
}
