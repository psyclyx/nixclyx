{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf optionals;
  cfg = config.psyclyx.hardware.drivers.usb;
in
{
  options = {
    psyclyx.hardware.drivers.usb = {
      enable = mkEnableOption "USB drivers";
      hid = mkEnableOption "USB HID" // {
        default = true;
      };
      storage = mkEnableOption "USB storage" // {
        default = true;
      };
      xhci = mkEnableOption "USB XHCI controller (USB 3, 2, 1)" // {
        default = true;
      };
      ehci = mkEnableOption "USB EHCI controller (USB 2)" // {
        default = true;
      };
      uhci = mkEnableOption "USB UHCI controller (USB 1)" // {
        default = true;
      };
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.availableKernelModules =
      (optionals cfg.hid [ "xhci_pci" ])
      ++ (optionals cfg.storage [ "xhci_pci" ])
      ++ (optionals cfg.xhci [ "xhci_pci" ])
      ++ (optionals cfg.ehci [ "ehci_pci" ])
      ++ (optionals cfg.uhci [ "uhci_pci" ]);
  };
}
