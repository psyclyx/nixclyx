# Environments — logical deployment contexts.
#
# Named env-* to avoid collision with network entities. The cluster
# envs (env-cluster-*) each own a dedicated network (`environment.network`
# points at the cluster-* VLAN entity); a VM in that env sits on its
# network's bridge. Logical-only envs that don't own a network leave
# `network = null`.
#
# See docs/lab-v3.md for the cluster topology.
{
  gate = "always";
  config = {
    entities = {
      env-cluster-prod = {
        type = "environment";
        environment = {
          site = "apt";
          domain = "prod.lab.psyclyx.net";
          network = "cluster-prod";
        };
      };
      env-cluster-stage = {
        type = "environment";
        environment = {
          site = "apt";
          domain = "stage.lab.psyclyx.net";
          network = "cluster-stage";
        };
      };
      env-cluster-scratch = {
        type = "environment";
        environment = {
          site = "apt";
          domain = "scratch.lab.psyclyx.net";
          network = "cluster-scratch";
        };
      };
      env-cluster-orch = {
        type = "environment";
        environment = {
          site = "apt";
          domain = "orch.lab.psyclyx.net";
          network = "cluster-orch";
        };
      };
    };
  };
}
