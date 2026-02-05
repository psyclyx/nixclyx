{
  path = ["psyclyx" "nixos" "hardware" "drivers" "usb"];
  description = "USB drivers";
  options = {lib, ...}: {
    hid =
      lib.mkEnableOption "USB HID"
      // {
        default = true;
      };
    storage =
      lib.mkEnableOption "USB storage"
      // {
        default = true;
      };
    xhci =
      lib.mkEnableOption "USB XHCI controller (USB 3, 2, 1)"
      // {
        default = true;
      };
    ehci =
      lib.mkEnableOption "USB EHCI controller (USB 2)"
      // {
        default = true;
      };
    uhci =
      lib.mkEnableOption "USB UHCI controller (USB 1)"
      // {
        default = true;
      };
  };
  config = {cfg, lib, ...}: {
    boot.initrd.availableKernelModules =
      (lib.optionals cfg.hid ["xhci_pci"])
      ++ (lib.optionals cfg.storage ["xhci_pci"])
      ++ (lib.optionals cfg.xhci ["xhci_pci"])
      ++ (lib.optionals cfg.ehci ["ehci_pci"])
      ++ (lib.optionals cfg.uhci ["uhci_hcd"]);
  };
}
