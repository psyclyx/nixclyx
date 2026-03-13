{
  patroni = {
    tls = {
      ca = "internal";
      sans = ["data" "rack"];
      ttl = "72h";
    };
    credentials = {
      replicator = { type = "database"; engine = "postgresql"; ttl = "1h"; };
      superuser = { type = "database"; engine = "postgresql"; ttl = "1h"; };
    };
  };

  etcd = {
    tls = {
      ca = "internal";
      sans = ["data"];
      ttl = "72h";
    };
  };

  redis = {
    credentials = {
      password = { type = "kv"; path = "redis/password"; };
    };
  };

  seaweedfs = {
    credentials = {
      s3-iam = { type = "kv"; path = "seaweedfs/s3-iam"; };
    };
  };

  attic = {
    tls = {
      ca = "internal";
      sans = ["rack"];
      ttl = "72h";
    };
    credentials = {
      db-password = { type = "kv"; path = "attic/db-password"; };
      token-secret = { type = "kv"; path = "attic/token-secret"; };
      s3-credentials = { type = "kv"; path = "attic/s3-credentials"; };
    };
  };
}
