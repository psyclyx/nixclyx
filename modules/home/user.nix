{ lib, ... }:
{
  options.psyclyx.user = {
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
