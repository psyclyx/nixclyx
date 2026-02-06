# nixclyx

NixOS configurations with SSH certificate PKI and WireGuard mesh networking.

## PKI Quick Reference

```bash
# Show current state
pki status

# Provision a peer (generates keys, signs certs, deploys)
pki provision <peer>

# Provision all peers
pki provision

# Check keys without signing
pki check <peer>

# Add a new WireGuard-only peer
pki add-peer <name>

# Sign an arbitrary public key
cat pubkey | pki sign host --principals "host1,host2" --identity "host1-host"
cat pubkey | pki sign user --principals "username" --identity "user@host"

# Enroll local workstation
pki enroll                 # user key only
pki enroll --host          # user + host keys

# Revoke certificates
pki revoke <serial> [serial...]
pki generate-krl
```

## Host Provisioning Workflow

1. Add peer entry to `pki/state.json` with IP addresses and FQDN
2. Boot the host with a temporary SSH key
3. Run `pki provision <hostname>`
4. Deploy NixOS configuration

## Directory Structure

```
pki/
  config.json    # Static config (CA paths, wireguard settings, DNS)
  state.json     # Dynamic state (peers, certs, serials)
packages/
  pki/           # Babashka PKI management tool
    src/pki/
      core.clj       # State management, serial tracking
      shell.clj      # Shell command helpers
      sign.clj       # Certificate signing
      provision.clj  # Remote provisioning
      cli.clj        # CLI entrypoint
modules/
  nixos/         # NixOS modules
  darwin/        # macOS modules
  home/          # home-manager modules
```
