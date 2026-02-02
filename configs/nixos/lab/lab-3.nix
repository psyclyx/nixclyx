{...}: {
  imports = [./base.nix];

  config = {
    networking.hostName = "lab-3";
    psyclyx.nixos = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "46840ce1-f854-4a96-a9cb-f5a9de9a15fb";
        boot = "2DDC-9E1D";
      };
    };
  };
}
