{
  path = ["psyclyx" "home" "info"];
  options = {lib, ...}: {
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
