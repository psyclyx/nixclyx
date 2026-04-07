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
          backend.local.port = 8081;
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
          backend.ha.lab-stage = "http";
          websockets = true;
          label = "Angelbeats";
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
