# SOPS guide

This repo uses `sops-nix` for both system-level and Home Manager secrets.

There are three main secret flows:

- system secrets for hosts, usually from `secrets/secrets.yaml`
- shared user secrets for Home Manager, from `secrets/secrets_common.yaml`
- encrypted SSH host snippets in `home/modules/features/ssh/ssh-hosts.yaml`

## Secret files used in this repo

| File | Purpose |
| --- | --- |
| `.sops.yaml` | recipient and creation-rule configuration |
| `secrets/secrets.yaml` | shared system/host secrets |
| `secrets/secrets_common.yaml` | shared Home Manager and identity secrets |
| `home/modules/features/ssh/ssh-hosts.yaml` | encrypted SSH host snippets for Home Manager |
| `hosts/work-wsl/100-PKROOTCA290-CA.yaml` | host-local work CA secret used by `work-nix-wsl` |

## System-side SOPS module

The NixOS wrapper lives at `modules/features/sops/`.

Available options:

- `cyberfighter.features.sops.enable`
- `cyberfighter.features.sops.defaultSopsFile`
- `cyberfighter.features.sops.sshKeyPath`
- `cyberfighter.features.sops.deployUserAgeKey`

### What it does

When enabled, the module:

- points `sops.defaultSopsFile` at the configured file
- uses the host SSH key as an `age` source via `sops.age.sshKeyPaths`
- stores the generated machine key at `/var/lib/sops-nix/key.txt`
- can derive a user-readable age key at `~/.config/sops/age/keys.txt` during activation when `deployUserAgeKey = true`

### Typical host usage

```nix
{
  cyberfighter.features.sops = {
    enable = true;
    defaultSopsFile = ../../secrets/secrets.yaml;
  };
}
```

### When to use `deployUserAgeKey`

Use `deployUserAgeKey = true` on hosts where the main user should be able to work with age-backed Home Manager or local SOPS workflows without manually copying a key out of the host.

Current examples in this repo include `sys-galp-nix` and `thkpd-pve1`.

## Home Manager SOPS module

The Home Manager wrapper lives at `home/modules/features/sops/`.

Available option:

- `cyberfighter.features.sops.enable`

### What it does

When enabled, it:

- uses `secrets/secrets_common.yaml`
- generates an age key at `~/.config/sops/age/keys.txt`
- exposes shared secrets such as:
  - `personal-info/fullname`
  - `personal-info/email`
  - `personal-info/github`
  - `personal-info/work-email`
  - `personal-info/work-github`

### Typical home usage

```nix
{
  cyberfighter.features.sops.enable = true;
}
```

Other modules can consume those shared secrets. In this repo, the `tools.jujutsu` submodule can use SOPS-backed identity values when `useSecretsForIdentity = true`.

## SSH host entries stored with SOPS

The Home Manager SSH module can read encrypted host entries from `home/modules/features/ssh/ssh-hosts.yaml`.

Relevant SSH options:

- `cyberfighter.features.ssh.enable`
- `cyberfighter.features.ssh.onepass`
- `cyberfighter.features.ssh.extraConfig`
- `cyberfighter.features.ssh.hosts`

Example:

```nix
{
  cyberfighter.features.ssh = {
    enable = true;
    onepass = true;
    hosts = [
      "thkpd-pve1"
      "simple-vm"
    ];
  };
}
```

The encrypted file is expected to store top-level aliases whose values are multiline SSH directives. Conceptually, entries look like this:

```yaml
my-server: |
  HostName 192.168.1.50
  User root
  IdentityFile ~/.ssh/id_ed25519
```

When `hosts` is non-empty and the encrypted file exists, the module:

- enables the Home Manager SOPS module by default
- decrypts the requested aliases
- renders an SSH include file from those aliases
- adds that include file to `~/.ssh/config`

## Adding a new host to secrets

The repo helper script is the fastest path:

```bash
./scripts/nixos-anywhere.sh \
  --hostname my-host \
  --target root@192.168.1.50 \
  --secrets \
  --ssh-host \
  --user cyberfighter
```

That flow is designed to help with:

- seeding or creating a host SSH key in 1Password
- converting the host public key into an age recipient
- updating `.sops.yaml`
- refreshing `secrets/secrets.yaml` and `secrets/secrets_common.yaml` via `sops updatekeys`
- adding the host alias to encrypted SSH host definitions
- adding that alias to one or more `home/<user>/home.nix` files

## Manual patterns

### Referencing a system secret

```nix
{
  sops.secrets."my-secret" = { };

  systemd.services.my-service.serviceConfig.EnvironmentFile =
    config.sops.secrets."my-secret".path;
}
```

### Referencing a game server secret

```nix
{
  cyberfighter.features.gameserver.astroneer.serverPasswordFile =
    config.sops.secrets."astroneer-server-password".path;
}
```

### Referencing a shared Home Manager secret

```nix
{
  cyberfighter.features.tools.jujutsu = {
    enable = true;
    useSecretsForIdentity = true;
  };
}
```

## Current repo usage

Current hosts use SOPS for things like:

- the shared host secrets file at `secrets/secrets.yaml`
- the work CA on `work-nix-wsl` via `hosts/work-wsl/100-PKROOTCA290-CA.yaml`
- Playit and Astroneer secrets on `vm-gameserver-nix`
- shared personal identity values for Home Manager
- encrypted SSH host aliases consumed by the Home Manager SSH module

## Troubleshooting

If a secret-backed setting is not appearing where expected, check:

- that the relevant module has `enable = true`
- that the host or user is present in the correct encrypted file's recipients
- that the referenced secret key exists
- that the consuming module points at `config.sops.secrets.<name>.path`
- that the machine has the expected age key available

For Home Manager SSH entries, also confirm that:

- the alias exists in `home/modules/features/ssh/ssh-hosts.yaml`
- the alias is listed in `cyberfighter.features.ssh.hosts`
- `cyberfighter.features.ssh.enable = true`

## Further reading

- `sops-nix`: <https://github.com/Mic92/sops-nix>
- `sops`: <https://github.com/getsops/sops>
- `age`: <https://age-encryption.org/>
