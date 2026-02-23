{
  path = ["psyclyx" "nixos" "services" "printing"];
  description = "Enable printing.";
  config = {pkgs, ...}: {
    services.printing = {
      enable = true;
      drivers = [pkgs.brlaser];
    };
  };
}
