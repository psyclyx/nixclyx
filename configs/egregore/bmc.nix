# iLO baseboard management controllers for lab hosts.
#
# Hostname is derived: ${entityName}.${mgmtZoneName} (e.g. lab-1-ilo.mgmt.apt.psyclyx.net).
# Model is the server hardware model — set here since it's not in the host entity.
{
  gate = "always";
  config = {
    entities = {
      lab-1-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-1";
        ilo.model = "DL360 Gen9";
      };
      lab-2-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-2";
        ilo.model = "DL360 Gen9";
      };
      lab-3-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-3";
        ilo.model = "DL360 Gen9";
      };
      lab-4-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-4";
        ilo.model = "DL360 Gen9";
      };
    };
  };
}
