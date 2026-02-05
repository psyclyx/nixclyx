{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "programs" "helix"];
  description = "helix text editor";
  config = _: {
    programs.helix = {
      enable = true;
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = lib.getExe pkgs.nixfmt;
            args = ["--strict"];
          };
        }
      ];
    };
  };
} args
