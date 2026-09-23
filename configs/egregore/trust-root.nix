# Fleet trust roots — the TPM-held key, the openbao seal oracle it
# unlocks, the tang servers backing clevis bindings, and the clevis
# bindings themselves. All single-instance today (everything sits on
# iyr); the schema supports redundancy by adding more entities and
# extending the relevant refs lists.
{
  gate = "always";
  config.entities = {
    iyr-tang = {
      
      tags = ["infra" "tang"];
      service = {
        kind = "tang";
        protocol = "http";
        # Tang advertises on iyr's infra address; the JWE blobs clients
        # carry embed that URL, so moving it means re-binding clevis on
        # anything already sealed. `reach` admits the clients that come
        # from another segment.
        backend.host = { host = "iyr"; network = "infra"; port = 7654; };
        audiences = [];
        reach = [ "main" ];
        label = "Tang (NBDE)";
      };
    };

    iyr-tpm-openbao-key = {
      
      refs.host = "iyr";
      tpm-key = { label = "openbao-seal"; keyType = "rsa"; bits = 2048; };
    };

    iyr-openbao-seal-oracle = {
      
      refs.host = "iyr";
      refs.tpmKey = "iyr-tpm-openbao-key";
      openbao-seal-oracle = {
        address = "https://10.0.25.1:8200";
        # iyr doesn't use preservation/`/persist`; co-locate the
        # init sentinel with the seal-oracle's existing state dir.
        initSentinel = "/var/lib/openbao-seal/.initialized";
      };
    };

    # Two clevis bindings on the same tank pool — persist and luns
    # are independent encryption roots that currently share a
    # passphrase. Modelled separately so the projection can emit
    # distinct bind/unlock units for each.
    tank-clevis-persist = {
      
      clevis-binding = {
        tangs = [ "iyr-tang" ];
        protectDataset = "tank-persist";
        # Shared blob between persist and luns — they have the same
        # passphrase today, so a single JWE unlocks both.
        secretFile = ../../hosts/nixos/lab-4/persist.jwe;
      };
    };
    tank-clevis-luns = {
      
      clevis-binding = {
        tangs = [ "iyr-tang" ];
        protectDataset = "tank-luns";
        secretFile = ../../hosts/nixos/lab-4/persist.jwe;
        # Consumers of bound datasets (e.g. the iSCSI target for luns
        # under tank/luns) wire their own dependencies on the unlock
        # unit via clevis-binding.attrs.unlockUnitName — no need to
        # list consumer unit names here.
      };
    };
    # Third encryptionroot on tank: lab-4's persistent OS root
    # (tank/host/lab-4/root). Same shared passphrase/blob as persist +
    # luns. Because that dataset is neededForBoot, the storage projection
    # classifies this as an initrd binding and unseals it in stage-1
    # before mounting `/`.
    tank-clevis-root = {
      
      clevis-binding = {
        tangs = [ "iyr-tang" ];
        protectDataset = "tank-host-lab-4-root";
        secretFile = ../../hosts/nixos/lab-4/persist.jwe;
      };
    };
  };
}
