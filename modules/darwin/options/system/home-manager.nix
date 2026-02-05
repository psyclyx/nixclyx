{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "darwin" "system" "home-manager"];
  description = "home-manager config";
  config = _: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {inherit nixclyx;};
      sharedModules = [
        (nixclyx.modules.home.options {inherit nixclyx;})
        (nixclyx.modules.home.config {inherit nixclyx;})
      ];
    };
  };
} args
