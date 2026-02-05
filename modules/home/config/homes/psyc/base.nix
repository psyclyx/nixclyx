{
  path = ["psyclyx" "home" "config" "homes" "psyc" "base"];
  description = "psyc base home config";
  config = {lib, ...}: {
    psyclyx.home = {
      info = {
        name = "psyclyx";
        email = "me@psyclyx.xyz";
      };

      programs = {
        fastfetch.enable = true;
        git.enable = true;
        ssh.enable = lib.mkDefault true;
        zsh.enable = lib.mkDefault true;
      };

      xdg.enable = true;
    };
  };
}
