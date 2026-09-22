# Sodola platform — render `config.sodola` to the hex `.bin`.
{ config, lib, pkgs, sodolaLib, ... }:
let
  s = config.sodola;
  json = {
    network = { inherit (s.network) ip netmask gateway; };
    auth = { inherit (s.auth) username; };
    ports = map (p: { mode = p.mode; native_vlan = p.nativeVlan; speed = p.speed; }) s.ports;
    vlans = map (v: { id = v.id; members = v.members; name = v.name; }) s.vlans;
    model = s.model;
    mgmt_vlan_hint = s.mgmtVlanHint;
    igmp_enabled = s.igmpEnabled;
  };
  jsonFile = pkgs.writeText "sodola-${s.model}.json" (builtins.toJSON json);
in {
  sodolaJson = json;
  system.build = {
    json = jsonFile;
    script = pkgs.runCommand "sodola-${s.model}.hex" { } ''
      ${sodolaLib.render}/bin/sodola-config generate --hex < ${jsonFile} > $out
    '';
  };
}
