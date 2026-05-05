# Services — named, reachable endpoints.
#
# Each service declares its domain (explicit or environment-derived), a
# backend (HA group VIP, remote host, or localhost on the ingress host),
# a protocol, and the audiences it's reachable in. The ingress projection
# composes everything else (HAProxy frontends, certs, DNS records) from
# this data plus the audience definitions and host capabilities.
#
# Multi-audience services (e.g. light) are reachable directly in each
# audience — no hairpin through a single global ingress host.
{
  gate = "always";
  config = {
    entities = {

      # --- Public HTTP (psyclyx.xyz) ---

      docs = {
        type = "service";
        tags = ["public" "static"];
        service = {
          domain = "docs.psyclyx.xyz";
          backend.local.port = 8084;
          audiences = ["public"];
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
          audiences = ["vpn"];
          label = "Metrics";
        };
      };

      torrent = {
        type = "service";
        tags = ["internal" "homelab"];
        service = {
          domain = "torrent.psyclyx.net";
          backend.host = { address = "172.16.0.2"; port = 8080; };
          audiences = ["vpn"];
          label = "Torrents";
        };
      };

      light = {
        type = "service";
        tags = ["internal" "homelab"];
        service = {
          domain = "light.psyclyx.net";
          # psyclight runs on iyr bound to localhost; HAProxy on iyr
          # terminates TLS for both apt-LAN and VPN clients.
          backend.local.port = 8080;
          streaming = true;
          audiences = ["apt" "vpn"];
          # apt's defaultIngress is iyr already; override vpn to iyr too
          # so road warriors hit iyr directly instead of hairpinning.
          ingress = { vpn = "iyr"; };
          label = "Lights";
        };
      };

      s3 = {
        type = "service";
        tags = ["internal" "monolyx" "infra"];
        service = {
          domain = "s3.psyclyx.net";
          backend.ha.lab = "s3";
          audiences = ["vpn"];
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
          audiences = ["vpn"];
          label = "WebDAV";
        };
      };

      openbao = {
        type = "service";
        tags = ["internal" "infra"];
        service = {
          domain = "openbao.psyclyx.net";
          backend.ha.lab = "openbao";
          audiences = ["vpn"];
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
          audiences = ["vpn"];
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
          audiences = ["vpn"];
          label = "Redis";
        };
      };

      # --- AngelBeats ---

      angelbeats-dl = {
        type = "service";
        tags = ["public" "monolyx"];
        service = {
          domain = "dl.angelbeats.me";
          # Direct to lab-2's vpn address — single-instance, no HA.
          backend.host = { address = "10.157.0.12"; port = 8092; };
          audiences = ["public"];
          label = "AngelBeats Downloads";
        };
      };

      # --- Public HTTP (llm) ---

      llm = {
        type = "service";
        tags = ["public"];
        service = {
          domain = "llm.psyclyx.xyz";
          backend.local.port = 8085;
          audiences = ["public"];
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
          audiences = ["public"];
          label = "Links";
        };
      };
    };
  };
}
