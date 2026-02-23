{
  path = ["psyclyx" "nixos" "hardware" "presets" "hpe" "dl20-gen10"];
  description = "HPE ProLiant DL20 Gen 10";
  config = {lib, ...}: {
    psyclyx.nixos = {
      hardware = {
        cpu.intel.enable = true;
        drivers = {
          usb.enable = true;
          scsi.enable = true;
        };

        ipmi.ilo.enable = true;
        storage.p408i-a-g10.enable = lib.mkDefault true;
      };
    };
  };
}
