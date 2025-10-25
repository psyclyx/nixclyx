{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.hardware.glasgow;

  # TODO: remove this once the regular one builds again
  glasgow =
    let
      patch = builtins.fetchurl {
        url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/453562.patch";
        sha = "sha256-aws9J5ZNUyz4Z2RqPVEovBTNng4AdhzS03Bqg8jejWQ=";
      };

      nixpkgs' =
        (pkgs.applyPatches {
          name = "nixpkgs-patched-glagow";
          src = inputs.nixpkgs;
          patches = [ patch ];
        }).src;

      pkgs' = import nixpkgs' {
        inherit (pkgs) system;
      };
    in
    pkgs'.glasgow;
in
{
  options.psyclyx.hardware.glasgow = {
    enable = lib.mkEnableOption "Glasgow digital interface explorer";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Users to put in the plugdev group";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.plugdev.members = cfg.users;
    services.udev.packages = [ glasgow ];
    environment.systemPackages = [ glasgow ];
  };
}
