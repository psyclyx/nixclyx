# Fleet trust roots — the TPM-held key, the openbao seal oracle it
# unlocks, the tang servers backing clevis bindings, and the clevis
# bindings themselves. All single-instance today (everything sits on
# iyr); the schema supports redundancy by adding more entities and
# extending the relevant refs lists.
{
  gate = "always";
  config = { config, lib, ... }: let
    # The fleet OpenBao endpoint, derived the same way
    # modules/nixos/derived/openbao-endpoint.nix derives it: the
    # `openbao` globals' scheme + the serverHost's address on
    # serverNetwork + port.
    #
    # This used to be the literal https://10.0.25.1:8200, which drifted
    # the moment iyr's infra address moved to .3 with the gateway
    # migration — the address is iyr's, so it has to come from iyr's
    # entry, not from a second copy here.
    obo = config.openbao or {};
    oboAddr = lib.attrByPath
      [ "entities" (obo.serverHost or "") "addresses" (obo.serverNetwork or "") "ipv4" ]
      "" config;
    oboEndpoint =
      "${obo.scheme or "https"}://${oboAddr}:${toString (obo.port or 8200)}";
  in {
    entities = {
      iyr-tang = {
        
        tags = ["infra" "tang"];
        service = {
          kind = "tang";
          protocol = "http";
          # Tang advertises on iyr's infra address; the JWE blobs clients
          # carry embed that URL, so moving it means re-binding clevis on
          # anything already sealed. `reach` admits the clients that come
          # from another segment.
          backend.host = { target = "iyr"; exposure = "iyr-tang"; };
          scopes = [];
          reach = [ "main" ];
          label = "Tang (NBDE)";
        };
      };
  
      # The tang listener on iyr (model §6) — declared beside the
      # offering that runs on it. Its `infra` scope is the network-named
      # address key iyr's infra address lives under.
      iyr.exposures.iyr-tang = {
        role = "backend";
        port = 7654;
        scopes = [ "infra" ];
        identity = null;
      };
  
      iyr-tpm-openbao-key = {
        
        refs.host = "iyr";
        tpm-key = { label = "openbao-seal"; keyType = "rsa"; bits = 2048; };
      };
  
      iyr-openbao-seal-oracle = {
        
        refs.host = "iyr";
        refs.tpmKey = "iyr-tpm-openbao-key";
        openbao-seal-oracle = {
          address = oboEndpoint;
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
          # unit via clevis-binding.unlockUnitName — no need to
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
  };
}
