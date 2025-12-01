pkgs:
let
  # Import individual environment groups
  coreEnv = import ./core.nix pkgs;
  modernEnv = import ./modern.nix pkgs;
  compressionEnv = import ./compression.nix pkgs;
  networkEnv = import ./network.nix pkgs;
  networkAdminEnv = import ./network-admin.nix pkgs;
  monitoringEnv = import ./monitoring.nix pkgs;
  ttyEnv = import ./tty.nix pkgs;
in
{
  # Expose individual groups as attributes
  core = coreEnv;
  modern = modernEnv;
  compression = compressionEnv;
  network = networkEnv;
  network-admin = networkAdminEnv;
  monitoring = monitoringEnv;
  tty = ttyEnv;

  # Combined environment with all groups
  # Usage: shell.full
  # Override: shell.full.override { monitoring = false; network-admin = false; }
  full = pkgs.lib.makeOverridable
    (
      {
        core ? true,
        modern ? true,
        compression ? true,
        network ? true,
        network-admin ? false,
        monitoring ? true,
        tty ? true,
      }:
      let
        selected = pkgs.lib.optionals core [ coreEnv ]
          ++ pkgs.lib.optionals modern [ modernEnv ]
          ++ pkgs.lib.optionals compression [ compressionEnv ]
          ++ pkgs.lib.optionals network [ networkEnv ]
          ++ pkgs.lib.optionals network-admin [ networkAdminEnv ]
          ++ pkgs.lib.optionals monitoring [ monitoringEnv ]
          ++ pkgs.lib.optionals tty [ ttyEnv ];
      in
      pkgs.buildEnv {
        name = "shell-full";
        paths = selected;
        meta.description = "Complete shell environment with all selected groups";
      }
    )
    { };
}
