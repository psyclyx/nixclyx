# Entity type: HPE iLO BMC.
{
  egregoreType = { lib, egregorLib, ... }: let
    rf = hostname: args:
      ''redfishtool -r "${hostname}" -u "$ILO_USER" -p "$ILO_PASSWORD" -S Always ${args}'';
  in {
    name = "ilo";
    description = "HPE Integrated Lights-Out baseboard management controller.";

    options = {
      hostname = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "iLO hostname for Redfish API. Null = derive from entity name + host site.";
      };
      model = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Server hardware model.";
      };
      mgmtNetwork = lib.mkOption {
        type = lib.types.str;
        default = "mgmt";
        description = "Network entity for deriving the management zone domain.";
      };
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Explicit management address. Null derives a hostname from the
          entity name + mgmt zone domain.

          Set this when the BMC is statically addressed: the derived name
          only resolves if the BMC took its address by DHCP and DDNS
          registered it, and a statically-configured BMC never takes a
          lease — so the reservation sits unused and the name never exists.
          A verb that resolves an unregistered name fails before it can
          report anything useful.
        '';
      };
    };

    deriveOptions = {
      address = lib.mkOption { type = lib.types.nullOr lib.types.str; };
      label = lib.mkOption { type = lib.types.str; };
    };

    derive = name: entity: egregore: let
      ilo = entity.ilo;
      # Derive hostname from entity name + mgmt zone domain if not explicit.
      mgmtNet = egregore.entities.${ilo.mgmtNetwork} or null;
      zoneName = if mgmtNet != null then mgmtNet.zoneName or null else null;
      derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
      resolvedHostname = if ilo.hostname != null then ilo.hostname else derivedHostname;
    in {
      address = resolvedHostname;
      label = if ilo.model != "" then ilo.model else name;
    };

  };
}
