{
  path = ["psyclyx" "nixos" "config" "roles" "server"];
  variant = ["psyclyx" "nixos" "role"];
  config = {lib, ...}: {
    psyclyx.nixos.config = {
      roles.base.enable = true;
      users.psyc.enable = true;
    };
    home-manager.users.psyc.psyclyx.home.variant = "server";
  };
}
