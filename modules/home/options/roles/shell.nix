{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "roles" "shell"];
  description = "Basic shell configuration and utilities";
  config = _: {
    psyclyx = {
      home = {
        programs = {
          ssh = {
            enable = lib.mkDefault true;
          };
          zsh = {
            enable = lib.mkDefault true;
          };
        };
      };
    };
  };
} args
