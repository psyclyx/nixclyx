# nixclyx

Public version of @psyclyx's homelab nix configuration.

# Cheat sheets

## ssh-keygen

### Generate keys

#### Host key

```bash
ssh-keygen -t ed25519 -N "" -C "" -f /etc/ssh/id_ed25519_host_key
ssh-keygen -t ed25519 -N "" -C "" -f /etc/secrets/initrd/id_ed25519_host_key
```

#### User key

```bash
ssh-keygen -t ed25519 -N "" -C "user@host" -f ~/.ssh/id_ed25519
```

### Extract public key from private key

```bash
ssh-keygen -y -f /etc/ssh/id_ed25519
```

### Sign keys (SSH CA)

#### Create a CA

```bash
ssh-keygen -t ed25519 -N "" -C "my-ca" -f ca_key
```

#### Sign a host key

```bash
ssh-keygen -s ca_key -I "hostname" -h -n "hostname,hostname.example.com" host_key.pub
# produces host_key-cert.pub
```

- `-h` marks it as a host certificate
- `-n` sets valid principals (hostnames)
- `-V +52w` to set validity (optional, default unlimited)

#### Sign a user key

```bash
ssh-keygen -s ca_key -I "user@example.com" -n "root,deploy" user_key.pub
# produces user_key-cert.pub
```

- `-n` sets valid principals (usernames the cert can log in as)
- `-V +90d` to set validity

### Inspect a certificate

```bash
ssh-keygen -L -f key-cert.pub
```

## Wireguard

### Generate keys

#### Private key

```bash
wg genkey > private.key
chmod 600 private.key
```

#### Public key (from private)

```bash
wg pubkey < private.key > public.key
```

#### Preshared key (optional, per-peer)

```bash
wg genpsk > preshared.key
```
