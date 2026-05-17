{nixclyx}: {lib, ...}: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports =
    [
      "${sources.home-manager}/nixos"
      (loadFlake sources.stylix).nixosModules.stylix
      "${sources.preservation}/module.nix"
      "${sources.disko}/module.nix"
      "${sources."microvm.nix"}/nixos-modules/host"
      modules.common
      "${sources.nixos-apple-silicon}/apple-silicon-support"
    ]
    ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

  config = {
    _module.args.nixclyx = nixclyx;
    system.stateVersion = "25.11";
    hardware.asahi.enable = lib.mkDefault false;
    # microvm.nix's host module defaults enable = true the moment you
    # import it. Flip the default so non-hypervisor hosts don't pull
    # in the microvms target, packages, and users.
    microvm.host.enable = lib.mkDefault false;
  };
}
