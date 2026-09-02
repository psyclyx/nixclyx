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

    attrs = name: entity: top: let
      ilo = entity.ilo;
      # Derive hostname from entity name + mgmt zone domain if not explicit.
      mgmtNet = top.entities.${ilo.mgmtNetwork} or null;
      zoneName = if mgmtNet != null then mgmtNet.attrs.zoneName or null else null;
      derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
      resolvedHostname = if ilo.hostname != null then ilo.hostname else derivedHostname;
    in {
      address = resolvedHostname;
      label = if ilo.model != "" then ilo.model else name;
    };

    verbs = name: entity: top: let
      host = (egregorLib.mkType {}).attrs name entity top; # can't self-reference attrs easily
      # Resolve hostname the same way as attrs
      ilo = entity.ilo;
      mgmtNet = top.entities.${ilo.mgmtNetwork} or null;
      zoneName = if mgmtNet != null then mgmtNet.attrs.zoneName or null else null;
      derivedHostname = if zoneName != null then "${name}.${zoneName}" else name;
      resolvedHostname =
        if ilo.address != null then ilo.address
        else if ilo.hostname != null then ilo.hostname
        else derivedHostname;

      # Desired BMC state, derived from the host this BMC belongs to.
      # Only the seats named in pxeInterfaces may network-boot; ilo-config
      # disables every other seat the firmware knows about, resolving seat
      # → NicBoot index against the BMC itself.
      hostEntity =
        let h = entity.refs.host or null;
        in if h != null then top.entities.${h} or null else null;
      hostBoot = if hostEntity != null then hostEntity.host.boot else {};
      seats = hostBoot.firmwareNics or {};
      pxeSeats = builtins.filter (n: seats ? ${n}) (hostBoot.pxeInterfaces or []);
      spec = {
        network_boot.pxe = map (n: {
          inherit (seats.${n}) adapter port;
        }) pxeSeats;

        # Pin PXE to IPv4 for hosts that netboot. This fleet's PXE path is
        # IPv4 by construction — reservations carry next-server/boot-file-name
        # and derived.pxe binds atftpd to IPv4 addresses — so there is no v6
        # chainload to find. Left on the firmware default ("Auto"), lab-4 was
        # observed reaching only the IPv6 boot entry: it sent a DHCPv6 solicit,
        # got an advertise with no boot options (correctly, since none are
        # served over v6), and gave up, while never emitting a single DHCPv4
        # frame from the IPv4 entry ahead of it in the boot order.
        bios = lib.optionalAttrs ((hostBoot.mode or "local") == "pxe") {
          UefiPxeBoot = "IPv4";
        };
      };
      specJson = builtins.toJSON spec;

      # Verbs take credentials from the environment rather than reaching
      # into sops themselves — same shape as power/info, and it keeps the
      # decision of where secrets live out of the entity type.
      iloCfg = sub: ''
        ilo-config ${sub} "${resolvedHostname}" <<'EGREGORE_EOF'
${specJson}
EGREGORE_EOF'';
    in {
      spec = {
        description = "Output the desired BMC configuration as JSON.";
        pure = true;
        impl = specJson;
      };
      plan = {
        description = "Show what would change on the BMC (no writes).";
        impl = iloCfg "apply --dry-run";
      };
      apply = {
        description = "Push the desired BMC configuration. BIOS changes are staged and take effect at the next host POST.";
        impl = iloCfg "apply";
      };
      power = {
        description = "Server power control (on|off|reset, or show state).";
        impl = ''
          action="''${1:-}"
          case "$action" in
            on)    ${rf resolvedHostname "Systems -F reset On"} ;;
            off)   ${rf resolvedHostname "Systems -F reset ForceOff"} ;;
            reset) ${rf resolvedHostname "Systems -F reset ForceRestart"} ;;
            "")    ${rf resolvedHostname "Systems -F get"} ;;
            *)     echo "Unknown power action: $action" >&2; exit 1 ;;
          esac
        '';
      };
      info = {
        description = "Show system information.";
        impl = rf resolvedHostname "Systems -F get";
      };
    };
  };
}
