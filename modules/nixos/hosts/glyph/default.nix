{
  path = ["psyclyx" "nixos" "hosts" "glyph"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./filesystems.nix];
  config = {
    lib,
    pkgs,
    nixclyx,
    ...
  }: {
    networking.hostName = "glyph";

    psyclyx.nixos = {
      hardware.presets.apple-silicon.enable = true;

      network.wireless.enable = true;

      services = {
        fstrim.enable = true;
        kanata.enable = true;
        resolved.enable = true;
      };

      role = "workstation";
    };

    stylix = {
      image = nixclyx.assets.wallpapers."4x-ppmm-city-night.jpg";
      polarity = "dark";
    };

    # Debug unit: runs between bcachefs unlock and sysroot mount in the initrd.
    # This is where the impermanence rollback will eventually happen:
    #   1. mv subvolumes/root/@live -> subvolumes/root/@<timestamp>
    #   2. prune old timestamped roots
    #   3. snapshot subvolumes/root/@blank -> subvolumes/root/@live
    boot.initrd.systemd.services.impermanence-debug = {
      description = "Debug: verify execution between bcachefs unlock and sysroot mount";
      wantedBy = ["initrd.target"];
      after = ["initrd-root-device.target"];
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        KeyringMode = "inherit";
      };
      script = ''
        set -euo pipefail
        mkdir -p /run/bcachefs-debug
        mount -t bcachefs /dev/disk/by-partlabel/nvme0-root /run/bcachefs-debug

        echo "=== IMPERMANENCE DEBUG ==="
        echo "Running between bcachefs unlock and sysroot mount."
        echo "This is where the rollback dance will happen."
        echo ""
        echo "Current root snapshots:"
        ls -la /run/bcachefs-debug/subvolumes/root/
        echo ""
        echo "@live contents:"
        ls -la /run/bcachefs-debug/subvolumes/root/@live/
        echo ""
        echo "@blank contents:"
        ls -la /run/bcachefs-debug/subvolumes/root/@blank/
        echo "=== END IMPERMANENCE DEBUG ==="

        umount /run/bcachefs-debug
        rmdir /run/bcachefs-debug
      '';
    };
  };
}
