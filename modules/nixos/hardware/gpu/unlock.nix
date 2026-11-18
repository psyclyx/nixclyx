{
  path = ["psyclyx" "nixos" "hardware" "gpu" "unlock"];
  description = "gpu_unlock: lift the GeForce half-rate FP16/BF16/TF32 tensor cap";
  options = {lib, ...}: {
    targets = lib.mkOption {
      type = lib.types.nonEmptyListOf (lib.types.strMatching "[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\\.[0-7]");
      example = ["0000:0d:00.0"];
      description = ''
        Full PCI addresses (`lspci -D`) of the cards to unlock. Deliberately
        no "all": name each card.
      '';
    };
    resume = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Re-unlock after suspend-to-RAM (a second firmware reset, before
        nvidia resumes the card). Suspend powers the card off, so without
        this it comes back locked.
      '';
    };
  };
  config = {cfg, config, lib, pkgs, ...}: let
    kmod = config.boot.kernelPackages.callPackage ../../../../packages/gpu-unlock/kmod.nix {};
  in {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64;
        message = "gpu_unlock: the firmware inputs are x86_64-only";
      }
      {
        # The module skips any card a driver already holds, so nvidia must
        # not be in the initrd (where it could win the race).
        assertion = !(builtins.elem "nvidia" config.boot.initrd.kernelModules);
        message = "gpu_unlock: nvidia must load after the initrd";
      }
    ];

    boot.extraModulePackages = [kmod];
    hardware.firmware = [pkgs.psyclyx.gpu-unlock-firmware];

    boot.kernelParams = [
      "gpu_unlock.targets=${lib.concatStringsSep "," cfg.targets}"
      "gpu_unlock.resume=${if cfg.resume then "1" else "0"}"
    ];

    # Loaded at the very start of stage 2, before anything can load nvidia
    # (udev coldplug, modules-load). Upstream loads from the initrd instead,
    # but the GSP firmware is ~85M of incompressible blob per initrd, and
    # the reset would blank the framebuffer under the ZFS passphrase
    # prompt. The firmware search path is set by activation, before
    # systemd starts. A failed unlock is logged, not fatal: the card stays
    # at stock rate unless its firmware wedges, which takes a full
    # power-off to clear.
    systemd.services.gpu-unlock = {
      description = "Unlock GeForce tensor throughput (gpu_unlock)";
      wantedBy = ["sysinit.target"];
      before = [
        "sysinit.target"
        "systemd-modules-load.service"
        "systemd-udev-trigger.service"
      ];
      unitConfig = {
        DefaultDependencies = false;
        # Skipped, not failed, when switching live into a generation that
        # first enables this: the booted module tree lacks gpu_unlock and
        # the cmdline lacks its targets until the next boot.
        ConditionKernelCommandLine = "gpu_unlock.targets";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
      };
    };

    # Rollback: a reboot keeps the card unlocked, so booting this entry
    # only returns to stock after a full power-off.
    specialisation.gpu-stock.configuration.psyclyx.nixos.hardware.gpu.unlock.enable = lib.mkForce false;
  };
}
