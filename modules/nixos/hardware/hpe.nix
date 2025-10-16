{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (inputs) self;
  inherit (lib)
    mkDefault
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  cfg = config.psyclyx.hardware.hpe;
in
{
  options = {
    psyclyx.hardware.hpe = {
      enable = mkEnableOption "HPE-specific hardware configuration";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      initrd.availableKernelModules = [
        "xhci_pci"
        "ehci_pci"
        "uhci_hcd"
        "hpsa"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "sr_mod"
        "sg"
      ];

      kernelModules = [ "kvm-intel" ];
    };

    environment.systemPackages = [ self.packages.${pkgs.system}.ssacli ];
  };
}
