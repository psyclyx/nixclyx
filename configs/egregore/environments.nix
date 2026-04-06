# Environments — logical deployment contexts.
#
# Named env-* to avoid collision with network entities (stage, prod VLANs).
# The VLAN is the L2/L3 segment; the environment is the logical context.
{
  gate = "always";
  config = {
    entities = {
      env-stage = {
        type = "environment";
        tags = ["staging"];
        environment = {
          domain = "stage.psyclyx.net";
          site = "apt";
        };
      };
      env-prod = {
        type = "environment";
        tags = ["production"];
        environment = {
          domain = "prod.psyclyx.net";
          site = "apt";
        };
      };
    };
  };
}
