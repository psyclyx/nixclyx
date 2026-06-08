{
  path = [
    "psyclyx"
    "egregore"
  ];
  gate = "always";
  imports = [
    ./wireguard.nix
    ./dns.nix
    ./dns-authority.nix
    ./dns-forwarding.nix
    ./monitoring.nix
    ./deployment.nix
    ./dhcp.nix
    ./ha.nix
    ./ha-services.nix
    ./zones.nix
    ./network.nix
    ./overlay.nix
    ./ingress.nix
    ./iscsi.nix
    ./nfs.nix
    ./pxe.nix
    ./storage.nix
    ./bootstrap.nix
    ./gateway.nix
    ./vms.nix
    ./openbao-fleet.nix
    ./openbao-vm-auth.nix
    ./openbao-vm-ssh-host.nix
    ./zvol-provision.nix
  ];

  extraOptions =
    { lib, ... }:
    {
      psyclyx.egregore = lib.mkOption {
        type = lib.types.anything;
        description = ''
          Evaluated egregore entity registry. Default is the shipped
          root spec; downstream consumers can override this with a
          registry built from a root that imports the shipped one via
          egregore's own module-import system.
        '';
      };
    };

  config =
    { lib, ... }:
    let
      spec = import ../../../egregore.nix;
      egregorePkg = import spec.lib { inherit lib; };
    in
    {
      psyclyx.egregore = egregorePkg.eval { modules = [spec.root]; };
    };
}
