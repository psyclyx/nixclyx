{
  path = ["psyclyx" "nixos" "programs" "nvf" "snacks"];
  gate = {config, ...}: config.psyclyx.nixos.programs.nvf.enable;
  config = {...}: {
    vim = {
      utility.snacks-nvim = {
        enable = true;
        setupOpts = {
          picker = {
            enabled = true;
          };
          bigfile = {
            enabled = true;
          };
          quickfile = {
            enabled = true;
          };
          input = {
            enabled = true;
          };
        };
      };
    };
  };
}
