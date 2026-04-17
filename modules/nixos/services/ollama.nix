{
  path = ["psyclyx" "nixos" "services" "ollama"];
  description = "Ollama local LLM inference server";
  options = {lib, ...}: {
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address Ollama listens on.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port Ollama listens on.";
    };
    acceleration = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["cuda" "rocm" "vulkan"]);
      default = null;
      description = "GPU acceleration backend (selects the appropriate ollama package variant).";
    };
    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "5m";
      description = "How long to keep models loaded in VRAM after last request.";
    };
    loadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Models to pull on service start.";
    };
    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables for Ollama.";
    };
  };
  config = {cfg, pkgs, lib, ...}: let
    packageFor = accel: {
      cuda = pkgs.ollama-cuda;
      rocm = pkgs.ollama-rocm;
      vulkan = pkgs.ollama-vulkan;
    }.${accel} or pkgs.ollama;
  in {
    services.ollama = {
      enable = true;
      host = cfg.host;
      port = cfg.port;
      package = lib.mkIf (cfg.acceleration != null) (packageFor cfg.acceleration);
      loadModels = cfg.loadModels;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = cfg.keepAlive;
      } // cfg.extraEnv;
    };
  };
}
