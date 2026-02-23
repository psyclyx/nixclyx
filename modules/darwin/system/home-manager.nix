{
  path = ["psyclyx" "darwin" "system" "home-manager"];
  description = "home-manager config";
  config = {nixclyx, ...}: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [nixclyx.modules.home];
    };
  };
}
