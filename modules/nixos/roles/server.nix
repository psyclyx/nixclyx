{
  path = ["psyclyx" "nixos" "roles" "server"];
  variant = ["psyclyx" "nixos" "role"];
  config = {lib, ...}: {
    psyclyx.nixos = {
      roles.base.enable = true;
      users.psyc.enable = true;
    };
    home-manager.users.psyc.psyclyx.home.profiles.psyc.base.enable = true;
  };
}
