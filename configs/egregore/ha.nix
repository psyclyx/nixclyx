# High-availability groups.
{
  gate = "always";
  config = {
    entities = {
      lab = {
        type = "ha-group";
        ha-group = {
          network = "infra";
          vip = {
            ipv4 = "10.0.25.200";
            ipv6 = "fd9a:e830:4b1e:19::c8";
          };
          vrid = 200;
          members = ["lab-1" "lab-2" "lab-3" "lab-4"];
          services = {
            s3         = { port = 8333; check = "/status"; };
            webdav     = { port = 7333; };
            postgresql = { port = 5432; mode = "tcp"; check = "/primary"; checkPort = 8008; };
            openbao    = { port = 8200; check = "/v1/sys/health?standbyok=true"; };
            redis      = { port = 6379; mode = "tcp"; };
          };
        };
      };

      lab-stage = {
        type = "ha-group";
        ha-group = {
          network = "stage";
          vip = {
            ipv4 = "10.0.31.200";
            ipv6 = "fd9a:e830:4b1e:1f::c8";
          };
          vrid = 201;
          members = ["lab-1" "lab-2" "lab-3" "lab-4"];
          services = {
            http  = { port = 80; };
            https = { port = 443; mode = "tcp"; };
          };
        };
      };
    };
  };
}
