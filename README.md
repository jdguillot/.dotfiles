# NixOS Setup Guide

## Obtaining Everything

### Get some basic packages

If the system does not already have git, gh, and bitwarden-cli then start with the following command.

```bash
nix-shell -p git git-crypt _1password-cli
```

### Clone the Repo

```bash
git clone https://github.com/jdguillot/.dotfiles.git
```

### Download secret key

Sign-in to 1password

```bash
eval $(op signin)
```

### Unlock git secrets

```bash
cd ~/.dotfiles
op read "op://Jonny/.dotfiles Secret Key/secret-key-base64" | base64 -d | git-crypt unlock /dev/stdin
```
