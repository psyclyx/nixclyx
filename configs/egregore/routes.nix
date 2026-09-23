# Static routes, as entities.
#
# Only the switches need these declared today: NixOS hosts get their
# default route from the network projection, and iyr's WAN failover is
# policy routing rather than a static default.
#
# The router-on-a-stick cutover is a one-line change here — `over`
# moves from `main` to `core-transit` — plus moving `refs.gateway` on
# the main network. Nothing else in the tree mentions the way off the
# switch any more.
{
  gate = "always";
  config = {
    entities = {
      mdf-agg01-default = {
        
        refs = { on = "mdf-agg01"; via = "iyr"; over = "core-transit"; };
        route = {
          dst = "0.0.0.0/0";
          comment = "iyr over core transit";
        };
      };

      # idf-dist01 and the other L2 switches carry a default route
      # declared-but-disabled: they don't route, but the entry is here
      # so enabling it is a data change rather than an improvisation at
      # 2am. Reached over mgmt, which is the only network they hold an
      # address on.
      idf-dist01-default = {
        
        refs = { on = "idf-dist01"; via = "iyr"; over = "mgmt"; };
        route = {
          dst = "0.0.0.0/0";
          disabled = true;
        };
      };
    };
  };
}
