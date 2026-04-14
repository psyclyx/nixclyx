# Sites — physical locations in the fleet.
{
  gate = "always";
  config = {
    entities = {
      apt = {
        type = "site";
        tags = ["apartment"];
        site = {
          location = "Seattle, WA — apartment";
          domain = "apt.psyclyx.net";
        };
      };
      cofractal-sea = {
        type = "site";
        tags = ["colo"];
        site = {
          location = "Seattle, WA — Cofractal colo";
          domain = "cofractal-sea.psyclyx.net";
        };
      };
      hetzner-pdx = {
        type = "site";
        tags = ["vps"];
        site = {
          location = "Hillsboro, OR — Hetzner";
          domain = "hetzner-pdx.psyclyx.net";
        };
      };
    };
  };
}
