{
  path = ["psyclyx" "darwin" "config" "roles" "desktop"];
  description = "desktop darwin role";
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    environment.systemPackages = nixclyx.packageGroups.dev pkgs;

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
