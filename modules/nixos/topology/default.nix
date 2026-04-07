{
  path = ["psyclyx" "egregore"];
  gate = "always";
  imports = [./wireguard.nix ./dns.nix ./monitoring.nix ./deployment.nix ./dhcp.nix ./ha.nix ./zones.nix ./network.nix ./ingress.nix];

  extraOptions = { lib, ... }: {
    psyclyx.egregore = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Evaluated egregore entity registry.";
    };
  };

  config = { lib, ... }: let
    spec = import ../../../egregore.nix;
    egregorePkg = import spec.lib { inherit lib; };
    result = egregorePkg.eval { inherit (spec) modules; };
  in {
    psyclyx.egregore = result;
  };
}
