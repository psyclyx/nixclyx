{nixclyx, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "home" "roles" "dev"];
  description = "Development tools and configuration";
  config = _: {
    psyclyx = {
      home = {
      };
    };
  };
} args
