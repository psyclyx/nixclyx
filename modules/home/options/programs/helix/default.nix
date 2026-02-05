{
  path = ["psyclyx" "home" "programs" "helix"];
  description = "helix text editor";
  config = {lib, pkgs, ...}: {
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
}
