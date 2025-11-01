{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    optionals
    types
    ;

  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz";

  cfg = config.psyclyx.users.psyc;
in
{
  options = {
    psyclyx.users.psyc = {
      enable = mkEnableOption "psyc user";
      admin = mkEnableOption "wheel group and trusted nix user";
      hmModules = mkOption {
        type = types.listOf types.any;
        default = [ inputs.self.homeManagerModules.homes.psyc.pc ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = optionals cfg.admin [ "psyc" ];

    users.users.psyc = {
      name = "psyc";
      shell = pkgs.zsh;
      isNormalUser = true;
      extraGroups = [ "video" ] ++ (optionals cfg.admin [ "wheel" ]);
      openssh.authorizedKeys.keys = publicKey;
    };

    home-manager.users.psyc.imports = cfg.hmModules;
  };
}
