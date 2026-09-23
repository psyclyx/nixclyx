# DNS views for the psyclyx fleet.
#
# Two views, split-horizon: one name resolves differently inside and
# outside. `records` names the record-set mechanism each view's names
# are answered from; scopes join a view with the `view` ref
# (see scopes.nix).
{
  gate = "always";
  config = {
    dnsViews = {
      public.records = "authoritative";
      internal.records = "localzone";
    };
  };
}
