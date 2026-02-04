{lib, ...}: {
  options.psyclyx.home.info = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "User's full name";
    };
    email = lib.mkOption {
      type = lib.types.str;
      description = "User's email";
    };
  };
}
