{lib, ...}: {
  options = {
    psyclyx.packageGroups = lib.mkOption {type = lib.types.anything;};
  };

  config = {
    psyclyx.packageGroups = import ./packageGroups.nix;
  };
}
