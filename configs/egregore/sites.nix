# Sites — physical locations in the fleet.
{
  gate = "always";
  config = {
    entities = {
      apt = {
        type = "site";
        tags = ["apartment"];
        refs.dns = "iyr";
        site = {
          location = "Seattle, WA — apartment";
          domain = "apt.psyclyx.net";
        };
      };
      cofractal-sea = {
        type = "site";
        tags = ["colo"];
        refs.dns = "tleilax";
        site = {
          location = "Seattle, WA — Cofractal colo";
          domain = "cofractal-sea.psyclyx.net";
        };
      };
      hetzner-pdx = {
        type = "site";
        tags = ["vps"];
        refs.dns = "semuta";
        site = {
          location = "Hillsboro, OR — Hetzner";
          domain = "hetzner-pdx.psyclyx.net";
        };
      };
    };
  };
}
