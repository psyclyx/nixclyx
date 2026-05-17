# NFS exports — paths shared by lab-4 to the rest of the lab.
#
# /nix-shared is the lab-4-built read-mostly Nix store, mounted at /nix
# on every PXE-booted lab host. Plaintext (no secrets live in the store).
#
# /persist holds the per-host state (machine-id, SSH host keys, sops
# creds, anything we want to survive reboots). Each consumer gets its
# own subdir on lab-4; lab-4 itself doesn't appear in any consumers
# list because it mounts /persist directly from its own tank pool.
{
  gate = "always";
  config = {
    entities = {
      nix-shared = {
        type = "nfs-export";
        refs.producer = "lab-4";
        nfs-export = {
          path = "/srv/nfs/nix";
          network = "lab";
          consumers = [
            "lab-1"
            "lab-2"
            "lab-3"
          ];
          readOnly = true;
          mountAt = "/nix";
          options = [
            "noatime"
            "ro"
          ];
        };
      };

      persist-lab-1 = {
        type = "nfs-export";
        refs.producer = "lab-4";
        nfs-export = {
          path = "/srv/nfs/persist/lab-1";
          network = "lab";
          consumers = [ "lab-1" ];
          mountAt = "/persist";
        };
      };

      persist-lab-2 = {
        type = "nfs-export";
        refs.producer = "lab-4";
        nfs-export = {
          path = "/srv/nfs/persist/lab-2";
          network = "lab";
          consumers = [ "lab-2" ];
          mountAt = "/persist";
        };
      };

      persist-lab-3 = {
        type = "nfs-export";
        refs.producer = "lab-4";
        nfs-export = {
          path = "/srv/nfs/persist/lab-3";
          network = "lab";
          consumers = [ "lab-3" ];
          mountAt = "/persist";
        };
      };
    };
  };
}
