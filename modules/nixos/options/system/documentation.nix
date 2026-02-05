{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "documentation"];
  description = "documentation generation";
  config = _: {
    documentation = {
      enable = true;
      dev.enable = true;
      doc.enable = true;
      info.enable = true;
      nixos = {
        enable = true;
        # Workaround: https://github.com/nix-community/stylix/issues/47
        # includeAllModules = true;
      };
    };
  };
} args
