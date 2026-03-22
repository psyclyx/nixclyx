{
  path = ["psyclyx" "nvf" "ai"];
  description = "AI assistant (avante)";
  options = {lib, ...}: {
    anthropicKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing Anthropic API key (read at neovim startup)";
    };
    openrouterKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing OpenRouter API key (read at neovim startup)";
    };
  };
  config = {cfg, lib, ...}: {
    vim = {
      assistant.avante-nvim = {
        enable = true;
        setupOpts = {
          provider = "claude";
          behaviour.auto_set_keymaps = true;
          hints.enabled = true;
          providers = {
            claude = {
              endpoint = "https://api.anthropic.com";
              model = "claude-opus-4-6";
              timeout = 30000;
              extra_request_body = {
                temperature = 0.75;
                max_tokens = 64000;
              };
            };
            claude-sonnet = {
              __inherited_from = "claude";
              model = "claude-sonnet-4-6";
            };
            openrouter = {
              __inherited_from = "openai";
              endpoint = "https://openrouter.ai/api/v1";
              api_key_name = "OPENROUTER_API_KEY";
              model = "anthropic/claude-sonnet-4-6";
            };
          };
        };
      };

      luaConfigRC.anthropic-key = lib.mkIf (cfg.anthropicKeyFile != null) (lib.nvim.dag.entryAnywhere ''
        local f = io.open("${cfg.anthropicKeyFile}", "r")
        if f then
          vim.env.ANTHROPIC_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
      '');

      luaConfigRC.openrouter-key = lib.mkIf (cfg.openrouterKeyFile != null) (lib.nvim.dag.entryAnywhere ''
        local f = io.open("${cfg.openrouterKeyFile}", "r")
        if f then
          vim.env.OPENROUTER_API_KEY = f:read("*a"):gsub("%s+$", "")
          f:close()
        end
      '');
    };
  };
}
