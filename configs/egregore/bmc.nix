# iLO baseboard management controllers for lab hosts.
{
  gate = "always";
  config = {
    entities = {
      lab-1-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-1";
        ilo = { hostname = "lab-1-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
      };

      lab-2-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-2";
        ilo = { hostname = "lab-2-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
      };

      lab-3-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-3";
        ilo = { hostname = "lab-3-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
      };

      lab-4-ilo = {
        type = "ilo"; tags = ["bmc" "lab"];
        refs.host = "lab-4";
        ilo = { hostname = "lab-4-ilo.mgmt.home.psyclyx.net"; model = "DL360 Gen9"; };
      };
    };
  };
}
