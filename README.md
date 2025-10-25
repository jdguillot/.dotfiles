# NixOS Setup Guide

## Obtaining Everything

### Get some basic packages

If the system does not already have git, gh, and bitwarden-cli then start with the following command

```bash
nix-shell -p git gh bitwarden-cli
```

### Clone the Repo

```bash
git clone https://github.com/jdguillot/.dotfiles.git
```

### Download secret key

Get the base64 encoded secret key from Bitwarden. **NOTE:** You will need to be on home network or Tailscale to get secret key.

```bash
bw config server https://vaultwarden.cyberfighter.space
export BW_SESSION=$(bw login --raw)
bw sync
bw get attachment secret-key-base64 --itemid 313a3cf9-365d-4463-9dc1-1a085c182122
base64 -d secret-key-base64 > secret-key
```

### Unlock git secrets

```bash
cd ~/.dotfiles
git-crypt unlock ../secret-key
```
