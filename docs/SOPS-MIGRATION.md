# SOPS Migration Guide

## Overview

This dotfiles repository is migrating from git-crypt to SOPS for all secrets management.

**Benefits of SOPS:**
- Age-based encryption (simpler than GPG)
- Per-secret encryption (git diffs show which secrets changed)
- Better integration with NixOS
- Templates for composing secrets at runtime
- Per-host access control

## Current State

### Already Using SOPS
- ✅ `pia-credentials` - PIA VPN login

### Needs Migration from git-crypt
- ❌ `smb-secrets` - TrueNAS/SMB credentials  
- ❌ `.ssh_config_work` - Work SSH configuration
- ❌ `100-PKROOTCA290-CA.crt` - Work CA certificate
- ❌ `nix.conf` - Additional Nix configuration

## Migration Steps

### Step 1: Add Secrets to SOPS

Edit `secrets/secrets.yaml` with SOPS:

```bash
sops secrets/secrets.yaml
```

Add the following secrets (example):

```yaml
# SMB/CIFS Credentials
smb-username: "Jonny"
smb-password: "your-password-here"

# Work SSH Config (if needed as separate secrets)
work-ssh-host: "work.example.com"
work-ssh-user: "your-username"
```

### Step 2: Update Modules

The following modules now use SOPS:

**Filesystems Module** (`modules/features/filesystems/`):
- Automatically creates SMB credentials from SOPS secrets
- Uses `smb-username` and `smb-password` from secrets.yaml
- Generates `/etc/nixos/smb-secrets` at runtime via SOPS templates

**VPN Module** (`modules/features/vpn/`):
- Uses `pia-credentials` from SOPS (already configured)

### Step 3: Remove git-crypt Files

Once secrets are in SOPS and tested:

```bash
# Remove old git-crypt encrypted files
rm secrets/smb-secrets

# Update .gitattributes to remove git-crypt filter
# (Keep 100-PKROOTCA290-CA.crt if needed as plain file)
```

### Step 4: Update README

Update the README.md to remove git-crypt references and document SOPS usage.

## SOPS Configuration

### Current `.sops.yaml`

```yaml
keys:
  - &cyberfighter age1059cfeyzas7ug20q7w39vwr8v9vj8rylxmhwl4p4uzh90hknyprq359wyd
  - &razer-nix age1g98hga3gn0qmtelwmcm3gpfpjpmt6zs60xww2vj7fk4v8n48qc5shnnvq3
  - &work-wsl age19ajzg046l44kdnmnc67hrffjdk8d4ufhc5luj2cf0zwrdj9ztq3ssw2rqu
  - &work-jdguillot age1exdsgk0hlf47ks2qf7jyls7k7q52e2d82306f3w859vyv3vqna5s4qygyc

creation_rules:
  - path_regex: secrets/secrets.yaml$
    key_groups:
    - age:
      - *cyberfighter
      - *razer-nix
      - *work-wsl
      - *work-jdguillot
```

### Adding New Host Keys

When setting up a new host:

1. Generate age key from SSH host key:
   ```bash
   nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
   ```

2. Add to `.sops.yaml`:
   ```yaml
   keys:
     - &new-host age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   
   creation_rules:
     - path_regex: secrets/secrets.yaml$
       key_groups:
       - age:
         - *new-host
   ```

3. Re-encrypt secrets:
   ```bash
   sops updatekeys secrets/secrets.yaml
   ```

## Using Secrets in Configurations

### Direct Secret Access

```nix
{
  sops.secrets.my-secret = {
    sopsFile = ../../secrets/secrets.yaml;
  };
  
  # Secret available at: /run/secrets/my-secret
}
```

### Secret Templates

Compose multiple secrets into a file:

```nix
{
  sops.secrets.smb-username = { };
  sops.secrets.smb-password = { };
  
  sops.templates."smb-credentials".content = ''
    username=${config.sops.placeholder.smb-username}
    password=${config.sops.placeholder.smb-password}
  '';
  
  # Template available at: config.sops.templates."smb-credentials".path
}
```

## Best Practices

1. **Never commit plaintext secrets** - Always use SOPS
2. **One secret per key** - Don't put multiple secrets in one SOPS key
3. **Use templates** - Compose secrets at runtime when needed
4. **Per-host access** - Only give hosts access to secrets they need
5. **Rotate regularly** - Update secrets and re-encrypt with `sops updatekeys`

## Troubleshooting

### "Failed to get the data key"

Make sure the host's age key is in `.sops.yaml` and run:
```bash
sops updatekeys secrets/secrets.yaml
```

### "Permission denied" on /run/secrets

Secrets are root-owned by default. Set ownership:
```nix
sops.secrets.my-secret = {
  owner = "myuser";
  group = "mygroup";
  mode = "0440";
};
```

### Editing Secrets

Always use `sops` command:
```bash
sops secrets/secrets.yaml
```

Never edit the encrypted file directly!
