{
  path = ["psyclyx" "nixos" "boot" "systemd" "loader"];
  description = "systemd-boot";
  config = {lib, ...}: {
    boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot = {
          enable = true;
          configurationLimit = 15;
          consoleMode = lib.mkDefault "max";
        };

        timeout = 1;
      };
    };
  };
}
