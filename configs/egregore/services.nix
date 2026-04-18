# Services — named, reachable endpoints.
#
# Each service gets a domain name (explicit or derived from environment),
# a backend (HA group VIP, remote host, or localhost on ingress), and
# a protocol (http or tcp).
#
# The ingress projection module reads these to generate haproxy config,
# DNS records, and ACME certs. The psyclyx-link package reads these to
# generate the links page.
{
  gate = "always";
  config = {
    entities = {

      # --- Public HTTP (psyclyx.xyz) ---

      login = {
        type = "service";
        tags = ["public" "monolyx"];
        service = {
          domain = "login.psyclyx.xyz";
          backend.local.port = 8080;
          label = "Login";
        };
      };

      docs = {
        type = "service";
        tags = ["public" "static"];
        service = {
          domain = "docs.psyclyx.xyz";
          backend.local.port = 8084;
          label = "Documentation";
        };
      };

      # --- Internal HTTP (psyclyx.net) ---

      metrics = {
        type = "service";
        tags = ["internal" "monitoring"];
        service = {
          domain = "metrics.psyclyx.net";
          backend.local.port = 2134;
          label = "Metrics";
        };
      };

      home-assistant = {
        type = "service";
        tags = ["internal" "homelab"];
        service = {
          domain = "ha.psyclyx.net";
          backend.host = { address = "10.0.110.100"; port = 8123; };
          websockets = true;
          label = "Home Assistant";
        };
      };

      torrent = {
        type = "service";
        tags = ["internal" "homelab"];
        service = {
          domain = "torrent.psyclyx.net";
          backend.host = { address = "172.16.0.2"; port = 8080; };
          label = "Torrents";
        };
      };

      s3 = {
        type = "service";
        tags = ["internal" "monolyx" "infra"];
        service = {
          domain = "s3.psyclyx.net";
          backend.ha.lab = "s3";
          check = "/status";
          label = "S3";
        };
      };

      webdav = {
        type = "service";
        tags = ["internal" "monolyx" "infra"];
        service = {
          domain = "webdav.psyclyx.net";
          backend.ha.lab = "webdav";
          label = "WebDAV";
        };
      };

      openbao = {
        type = "service";
        tags = ["internal" "infra"];
        service = {
          domain = "openbao.psyclyx.net";
          backend.ha.lab = "openbao";
          check = "/v1/sys/health?standbyok=true";
          label = "OpenBao";
        };
      };

      # --- Internal TCP (DNS only, no ingress proxy) ---

      postgresql = {
        type = "service";
        tags = ["internal" "monolyx" "infra"];
        service = {
          domain = "postgresql.psyclyx.net";
          protocol = "tcp";
          backend.ha.lab = "postgresql";
          label = "PostgreSQL";
        };
      };

      redis = {
        type = "service";
        tags = ["internal" "monolyx" "infra"];
        service = {
          domain = "redis.psyclyx.net";
          protocol = "tcp";
          backend.ha.lab = "redis";
          label = "Redis";
        };
      };

      # --- Stage HTTP (environment-scoped) ---

      angelbeats = {
        type = "service";
        tags = ["monolyx"];
        service = {
          environment = "env-stage";
          # Direct to lab-2 rather than via the lab-stage HA VIP:
          # the VIP is unreachable from tleilax because lab-1's policy
          # routing has no `from 10.0.31.200 lookup 31` rule, so replies
          # from the VIP leak out bond0.25 instead of bond0.31. Follow-up
          # fix belongs in nixclyx topology; for now point directly.
          backend.host = { address = "10.0.31.12"; port = 80; };
          websockets = true;
          label = "Angelbeats";
        };
      };

      login-stage = {
        type = "service";
        tags = ["monolyx"];
        service = {
          domain = "login.stage.psyclyx.net";
          backend.host = { address = "10.0.31.11"; port = 8080; };
          label = "Login (Stage)";
        };
      };

      # --- Public HTTP (llm) ---

      llm = {
        type = "service";
        tags = ["public"];
        service = {
          domain = "llm.psyclyx.xyz";
          backend.local.port = 8085;
          websockets = true;
          label = "LLM Chat";
        };
      };

      # --- Static sites (served by nginx on localhost) ---
      # psyclyx.link is split-horizon: public and internal variants on
      # different nginx ports. The ingress host config wires the split;
      # here we just declare the public-facing service.

      links = {
        type = "service";
        tags = ["public" "static"];
        service = {
          domain = "psyclyx.link";
          backend.local.port = 8082;
          label = "Links";
        };
      };
    };
  };
}
