{ inputs, ... }:
{
  imports = [ inputs.self.homeManagerModules.config ];

  config = {
    psyclyx = {
      user = {
        name = "psyclyx";
        email = "me@psyclyx.xyz";
        roles.shell.enable = true;
      };
    };
  };

}
