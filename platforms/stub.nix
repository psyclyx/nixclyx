# Stub platform backend — device exists in fleet data (appears in
# visualization and validation) but has no config generation or deployment.
# Use this for devices you haven't written a backend for yet.
{ device, fleet, pkgs }: {
  configFile = null;
  deploy = null;
}
