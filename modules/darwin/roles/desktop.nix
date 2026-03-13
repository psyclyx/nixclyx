{
  path = ["psyclyx" "darwin" "roles" "desktop"];
  description = "desktop darwin role";
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    environment.systemPackages =
      nixclyx.packageGroups.dev pkgs
      ++ nixclyx.packageGroups.media pkgs;

    psyclyx.darwin = {
      programs = {
        firefox.enable = lib.mkDefault true;
        raycast.enable = lib.mkDefault true;
      };
      services = {
        aerospace.enable = lib.mkDefault true;
        sketchybar.enable = lib.mkDefault true;
      };
    };
  };
}
