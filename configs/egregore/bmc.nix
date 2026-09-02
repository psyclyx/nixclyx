# iLO baseboard management controllers for lab hosts.
#
# Model is the server hardware model — set here since it's not in the host
# entity. Desired BMC settings are not declared here: they derive from the
# referenced host (boot.pxeInterfaces ∩ boot.firmwareNics), so `ilo plan`
# and `ilo apply` follow the host's PXE intent without a second place to
# keep in sync.
#
# Addresses are explicit because these BMCs are statically configured. Kea
# holds a mgmt reservation for each (from the host's mac.mgmt), but a static
# BMC never takes the lease, so DDNS never publishes
# <name>.mgmt.apt.psyclyx.net and the derived hostname does not resolve.
# Worth reconciling later — either let the BMCs DHCP, or emit these into the
# zone from the reservation rather than depending on DDNS.
{
  gate = "always";
  config = {
    entities = {
      lab-1-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-1";
        ilo = { model = "DL360 Gen9"; address = "10.0.240.11"; };
      };
      lab-2-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-2";
        ilo = { model = "DL360 Gen9"; address = "10.0.240.12"; };
      };
      lab-3-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-3";
        ilo = { model = "DL360 Gen9"; address = "10.0.240.13"; };
      };
      lab-4-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-4";
        ilo = { model = "DL360 Gen9"; address = "10.0.240.14"; };
      };
    };
  };
}
