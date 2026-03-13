{
  lab = {
    network = "rack";
    vip = {
      ipv4 = "10.157.10.200";
      ipv6 = "fd9a:e830:4b1e:14::c8";
    };
    vrid = 200;
    members = ["lab-1" "lab-2" "lab-3" "lab-4"];
    services = {
      s3         = { port = 8333; check = "/status"; };
      webdav     = { port = 7333; };
      attic      = { port = 8080; check = "/"; };
      postgresql = { port = 5432; mode = "tcp"; check = "/primary"; checkPort = 8008; };
    };
  };
}
