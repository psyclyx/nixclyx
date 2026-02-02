pkgs: let
  # Import individual environment groups
  coreEnv = import ./core.nix pkgs;
  modernEnv = import ./modern.nix pkgs;
  compressionEnv = import ./compression.nix pkgs;
  networkEnv = import ./network.nix pkgs;
  networkAdminEnv = import ./network-admin.nix pkgs;
  monitoringEnv = import ./monitoring.nix pkgs;
  ttyEnv = import ./tty.nix pkgs;

  # Combined environment with all groups
  fullShell = pkgs.buildEnv {
    name = "shell-full";
    paths = [
      coreEnv
      modernEnv
      compressionEnv
      networkEnv
      networkAdminEnv
      monitoringEnv
      ttyEnv
    ];
    meta.description = "Complete shell environment with all groups";
  };
in
  # Return the full shell derivation with individual groups as attributes
  fullShell
  // {
    core = coreEnv;
    modern = modernEnv;
    compression = compressionEnv;
    network = networkEnv;
    network-admin = networkAdminEnv;
    monitoring = monitoringEnv;
    tty = ttyEnv;
  }
