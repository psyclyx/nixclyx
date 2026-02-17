{
  path = ["psyclyx" "topology"];
  gate = false;
  imports = [./wireguard.nix ./dns.nix ./monitoring.nix ./deployment.nix];
}
