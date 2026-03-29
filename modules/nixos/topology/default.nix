{
  path = ["psyclyx" "egregore"];
  gate = "always";
  imports = [./wireguard.nix ./dns.nix ./monitoring.nix ./deployment.nix ./dhcp.nix ./ha.nix];

  extraOptions = { lib, ... }: {
    psyclyx.egregore = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      description = "Evaluated egregore entity registry.";
    };
  };

  config = { lib, ... }: let
    egregorePkg = import ../../../egregore { inherit lib; };
    result = egregorePkg.eval {
      modules = [
        ../../../egregore/extensions/globals.nix
        ../../../egregore/types/network.nix
        ../../../egregore/types/host.nix
        ../../../egregore/types/routeros.nix
        ../../../egregore/types/swos.nix
        ../../../egregore/types/sodola.nix
        ../../../egregore/types/ilo.nix
        ../../../egregore/types/unmanaged.nix
        ../../../egregore/types/ha-group.nix
        ../../../data/egregore.nix
      ];
    };
  in {
    psyclyx.egregore = result;
  };
}
